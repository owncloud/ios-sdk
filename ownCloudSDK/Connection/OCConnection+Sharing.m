//
//  OCConnection+Sharing.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 01.03.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

/*
	References:
	- Developer documentation: https://doc.owncloud.com/server/developer_manual/core/ocs-share-api.html
	- Implementation: https://github.com/owncloud/core/blob/master/apps/files_sharing/lib/Controller/Share20OcsController.php
*/

#import "OCConnection.h"
#import "OCItem.h"
#import "NSError+OCError.h"
#import "OCXMLParser.h"
#import "OCXMLParserNode.h"
#import "OCShare+OCXMLObjectCreation.h"
#import "OCLogger.h"
#import "NSDate+OCDateParser.h"
#import "NSProgress+OCEvent.h"
#import "OCMacros.h"
#import "NSProgress+OCExtensions.h"
#import "OCHTTPResponse+DAVError.h"
#import "OCHTTPDAVRequest.h"
#import "NSString+OCPath.h"
#import "NSURL+OCPrivateLink.h"

@interface OCSharingResponseStatus : NSObject <OCXMLObjectCreation>

@property(strong) NSString *status;
@property(strong) NSNumber *statusCode;

@property(strong) NSString *message;

@property(strong,nonatomic) NSError *error;

@end

@implementation OCSharingResponseStatus

+ (NSString *)xmlElementNameForObjectCreation
{
	return (@"meta");
}

+ (instancetype)instanceFromNode:(OCXMLParserNode *)metaNode xmlParser:(OCXMLParser *)xmlParser
{
	OCSharingResponseStatus *responseStatus = [self new];

	responseStatus.status = metaNode.keyValues[@"status"];

	if (metaNode.keyValues[@"statuscode"] != nil)
	{
		responseStatus.statusCode = @(((NSString *)metaNode.keyValues[@"statuscode"]).integerValue);
	}

	responseStatus.message = metaNode.keyValues[@"message"];

	xmlParser.userInfo[@"sharingResponseStatus"] = responseStatus;

	return (nil);
}

- (instancetype)initWithHTTPStatus:(OCHTTPStatus *)status
{
	if ((self = [super init]) != nil)
	{
		_statusCode = @(status.code);
		_error = status.error;
	}

	return (self);
}

- (NSError *)error
{
	if (_error == nil)
	{
		_error = OCErrorWithDescription(OCErrorUnknown, _message);
	}

	return (_error);
}

@end

@interface OCShareSingle : OCShare
@end

@implementation OCShareSingle

+ (NSString *)xmlElementNameForObjectCreation
{
	return (@"data");
}

@end

@implementation OCConnection (Sharing)

#pragma mark - Retrieval
- (NSArray<OCShare *> *)_parseSharesResponse:(OCHTTPResponse *)response data:(NSData *)responseData error:(NSError **)outError status:(OCSharingResponseStatus **)outStatus statusErrorMapper:(NSError*(^)(OCSharingResponseStatus *status))statusErrorMapper
{
	OCXMLParser *parser = nil;
	NSError *error;

	if (error == nil)
	{
		if ((parser = [[OCXMLParser alloc] initWithData:responseData]) != nil)
		{
			[parser addObjectCreationClasses:@[ [OCShare class], [OCShareSingle class], [OCSharingResponseStatus class] ]];

			if ([parser parse])
			{
				OCSharingResponseStatus *status = parser.userInfo[@"sharingResponseStatus"];

				OCLogDebug(@"Parsed objects: %@, status=%@", parser.parsedObjects, status);

				if ((error = parser.errors.firstObject) == nil)
				{
					if (statusErrorMapper != nil)
					{
						if (status != nil)
						{
							error = statusErrorMapper(status);
						}
						else
						{
							// Incomplete response
							error = OCError(OCErrorResponseUnknownFormat);
						}
					}
				}

				if (outStatus != NULL)
				{
					*outStatus = status;
				}
			}
		}
	}

	if ((response != nil) && !response.status.isSuccess && (error == nil) && (statusErrorMapper != nil))
	{
		error = statusErrorMapper([[OCSharingResponseStatus alloc] initWithHTTPStatus:response.status]);
	}

	if (outError != NULL)
	{
		*outError = error;
	}

	return (parser.parsedObjects);
}

- (nullable NSProgress *)retrieveSharesWithScope:(OCShareScope)scope forItem:(nullable OCItem *)item options:(nullable NSDictionary *)options completionHandler:(OCConnectionShareRetrievalCompletionHandler)completionHandler
{
	OCHTTPRequest *request;
	NSProgress *progress = nil;
	NSURL *url = [self URLForEndpoint:OCConnectionEndpointIDShares options:nil];

	request = [OCHTTPRequest new];
	request.requiredSignals = self.propFindSignals;

	switch (scope)
	{
		case OCShareScopeItem:
		case OCShareScopeItemWithReshares:
		case OCShareScopeSubItems:
		break;

		default:
			if (item != nil)
			{
				OCLogWarning(@"item=%@ ignored for retrieval of shares with scope=%lu", item, scope);
			}
		break;
	}

	switch (scope)
	{
		case OCShareScopeSharedByUser:
			// No options to set
		break;

		case OCShareScopeSharedWithUser:
			[request setValue:@"true" forParameter:@"shared_with_me"];
			[request setValue:@"all" forParameter:@"state"];
		break;

		case OCShareScopePendingCloudShares:
			url = [[self URLForEndpoint:OCConnectionEndpointIDRemoteShares options:nil] URLByAppendingPathComponent:@"pending"];
		break;

		case OCShareScopeAcceptedCloudShares:
			url = [self URLForEndpoint:OCConnectionEndpointIDRemoteShares options:nil];
		break;

		case OCShareScopeItem:
		case OCShareScopeItemWithReshares:
		case OCShareScopeSubItems:
			if (item == nil)
			{
				OCLogError(@"item required for retrieval of shares with scope=%lu", scope);

				if (completionHandler != nil)
				{
					completionHandler(OCError(OCErrorInsufficientParameters), nil);
				}

				return (nil);
			}

			[request setValue:item.path forParameter:@"path"];

			if (scope == OCShareScopeItemWithReshares)
			{
				[request setValue:@"true" forParameter:@"reshares"];
			}

			if (scope == OCShareScopeSubItems)
			{
				[request setValue:@"true" forParameter:@"subfiles"];
			}
		break;
	}

	request.url = url;

	progress = [self sendRequest:request ephermalCompletionHandler:^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
		OCSharingResponseStatus *status = nil;
		NSArray <OCShare *> *shares = nil;

		if (error == nil)
		{
			shares = [self _parseSharesResponse:response data:response.bodyData error:&error status:&status statusErrorMapper:^NSError *(OCSharingResponseStatus *status) {
				NSError *error = nil;

				switch (status.statusCode.integerValue)
				{
					case 100:
					case 200:
						// Successful
					break;

					case 400:
						// Not a directory (fetching shares for directory)
						error = OCErrorWithDescription(OCErrorShareItemNotADirectory, status.message);
					break;

					case 404:
						switch (scope)
						{
							case OCShareScopeSharedByUser:
							case OCShareScopeSharedWithUser:
								// Couldn't fetch shares (fetching all shares)
								error = OCErrorWithDescription(OCErrorShareUnavailable, status.message);
							break;

							case OCShareScopeItem:
							case OCShareScopeItemWithReshares:
								// File doesn't exist (fetching shares for file)
								error = OCErrorWithDescription(OCErrorShareItemNotFound, status.message);
							break;

							default:
								// Unknown error
								error = status.error;
							break;
						}
					break;

					case 997:
						// Unauthorized
						error = OCErrorWithDescription(OCErrorShareUnauthorized, status.message);
					break;

					default:
						// Unknown error
						error = OCErrorWithDescription(OCErrorUnknown, status.message);
					break;
				}

				return (error);
			}];
		}

		completionHandler(error, (error == nil) ? shares : nil);
	}];

	return (progress);
}

- (nullable NSProgress *)retrieveShareWithID:(OCShareID)shareID options:(nullable NSDictionary *)options completionHandler:(OCConnectionShareCompletionHandler)completionHandler
{
	OCHTTPRequest *request;
	NSProgress *progress = nil;

	request = [OCHTTPRequest requestWithURL:[[self URLForEndpoint:OCConnectionEndpointIDShares options:nil] URLByAppendingPathComponent:shareID]];
	request.requiredSignals = self.propFindSignals;

	progress = [self sendRequest:request ephermalCompletionHandler:^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
		OCSharingResponseStatus *status = nil;
		NSArray <OCShare *> *shares = nil;

		if (!((response.error != nil) && ![response.error.domain isEqual:OCHTTPStatusErrorDomain]))
		{
			shares = [self _parseSharesResponse:response data:response.bodyData error:&error status:&status statusErrorMapper:^NSError *(OCSharingResponseStatus *status) {
					NSError *error = nil;

					switch (status.statusCode.integerValue)
					{
						case 100:
						case 200:
							// Successful
						break;

						case 404:
							// Share does not exist
							error = OCErrorWithDescription(OCErrorShareNotFound, status.message);
						break;

						default:
							// Unknown error
							error = status.error;
						break;
					}

					return (error);
				}];
		}

		completionHandler(error, (error == nil) ? shares.firstObject : nil);
	}];

	return (progress);
}

#pragma mark - Creation and deletion
- (nullable OCProgress *)createShare:(OCShare *)share options:(nullable OCShareOptions)options resultTarget:(OCEventTarget *)eventTarget
{
	OCHTTPRequest *request;
	OCProgress *requestProgress = nil;

	request = [OCHTTPRequest requestWithURL:[self URLForEndpoint:OCConnectionEndpointIDShares options:nil]];
	request.method = OCHTTPMethodPOST;
	request.requiredSignals = self.propFindSignals;

	if (share.name != nil)
	{
		[request setValue:share.name forParameter:@"name"];
	}

	[request setValue:[NSString stringWithFormat:@"%ld", share.type] forParameter:@"shareType"];

	[request setValue:share.itemPath forParameter:@"path"];

	[request setValue:[NSString stringWithFormat:@"%ld", share.permissions] forParameter:@"permissions"];

	if (share.expirationDate != nil)
	{
		[request setValue:share.expirationDate.compactUTCStringDateOnly forParameter:@"expireDate"];
	}

	if (share.type != OCShareTypeLink)
	{
		[request setValue:share.recipient.identifier forParameter:@"shareWith"];
	}

	if (share.password != nil)
	{
		[request setValue:share.password forParameter:@"password"];
	}

	request.resultHandlerAction = @selector(_handleCreateShareResult:error:);
	request.eventTarget = eventTarget;

	request.forceCertificateDecisionDelegation = YES;

	[self.commandPipeline enqueueRequest:request forPartitionID:self.partitionID];

	requestProgress = request.progress;
	requestProgress.progress.eventType = OCEventTypeCreateShare;
	requestProgress.progress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Creating share for %@…"), share.itemPath.lastPathComponent];

	return (requestProgress);
}

- (void)_handleCreateShareResult:(OCHTTPRequest *)request error:(NSError *)error
{
	OCEvent *event;

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeCreateShare uuid:request.identifier attributes:nil]) != nil)
	{
		if ((request.error != nil) && ![request.error.domain isEqual:OCHTTPStatusErrorDomain])
		{
			event.error = request.error;
		}
		else
		{
			NSArray <OCShare *> *shares = nil;

			shares = [self _parseSharesResponse:request.httpResponse data:request.httpResponse.bodyData error:&error status:NULL statusErrorMapper:^NSError *(OCSharingResponseStatus *status) {
				NSError *error = nil;

				switch (status.statusCode.integerValue)
				{
					case 100:
					case OCHTTPStatusCodeOK: // 200
						// Successful
					break;

					case OCHTTPStatusCodeBAD_REQUEST: // 400
						// Not a directory (fetching shares for directory)
						error = OCErrorWithDescription(OCErrorShareUnknownType, status.message);
					break;

					case OCHTTPStatusCodeFORBIDDEN: // 403
						// Public upload was disabled by the admin
						error = OCErrorWithDescription(OCErrorSharePublicUploadDisabled, status.message);
					break;

					case OCHTTPStatusCodeNOT_FOUND: // 404
						// File or folder couldn’t be shared
						error = OCErrorWithDescription(OCErrorShareItemNotFound, status.message);
					break;

					default:
						// Unknown error
						error = status.error;
					break;
				}

				return (error);
			}];

			event.result = shares.firstObject;
			event.error = error;
		}
	}

	if (event != nil)
	{
		[request.eventTarget handleEvent:event sender:self];
	}
}

- (nullable OCProgress *)updateShare:(OCShare *)share afterPerformingChanges:(void(^)(OCShare *share))performChanges resultTarget:(OCEventTarget *)eventTarget
{
	// Save previous values of editable properties
	NSString *previousName = share.name;
	NSString *previousPassword = share.password;
	BOOL previousProtectedByPassword = share.protectedByPassword;
	NSDate *previousExpirationDate = share.expirationDate;
	OCSharePermissionsMask previousPermissions = share.permissions;
	NSMutableDictionary<NSString *,NSString *> *changedValuesByPropertyNames = [NSMutableDictionary new];
	NSMutableDictionary *userInfo = [NSMutableDictionary new];
	BOOL returnLinkShareOnlyError = NO;

	// Perform changes
	share = [share copy];
	performChanges(share);

	// Compare and detect changes
	if (OCNANotEqual(share.name, previousName))
	{
		if (share.type == OCShareTypeLink)
		{
			changedValuesByPropertyNames[@"name"] = (share.name != nil) ? share.name : @"";
		}
		else
		{
			returnLinkShareOnlyError = YES;
		}
	}

	if ((OCNANotEqual(share.password, previousPassword)) || (share.protectedByPassword != previousProtectedByPassword))
	{
		if ((share.protectedByPassword != previousProtectedByPassword) && (previousProtectedByPassword))
		{
			// Remove password
			share.password = @"";
		}

		if (share.type == OCShareTypeLink)
		{
			changedValuesByPropertyNames[@"password"] = (share.password != nil) ? share.password : @"";
		}
		else
		{
			returnLinkShareOnlyError = YES;
		}
	}

	if (OCNANotEqual(share.expirationDate, previousExpirationDate))
	{
		if (share.type == OCShareTypeLink)
		{
			changedValuesByPropertyNames[@"expireDate"] = (share.expirationDate != nil) ? share.expirationDate.compactUTCStringDateOnly : @"";
		}
		else
		{
			returnLinkShareOnlyError = YES;
		}
	}

	if (share.permissions != previousPermissions)
	{
		changedValuesByPropertyNames[@"permissions"] = [NSString stringWithFormat:@"%ld", share.permissions];
	}

	if (returnLinkShareOnlyError)
	{
		[eventTarget handleError:OCErrorWithDescription(OCErrorFeatureNotSupportedByServer, @"Updating the name, password and expiryDate is only supported for shares of type link") type:OCEventTypeUpdateShare uuid:nil sender:self];
		return (nil);
	}

	if (changedValuesByPropertyNames.count == 0)
	{
		// No changes => return immediately
		[eventTarget handleEvent:[OCEvent eventForEventTarget:eventTarget type:OCEventTypeUpdateShare uuid:nil attributes:nil] sender:self];
		return (nil);
	}
	else
	{
		// Changes => schedule requests
		userInfo[@"shareID"] = share.identifier;
		userInfo[@"updateProperties"] = changedValuesByPropertyNames;

		return ([self _scheduleShareUpdateWithUserInfo:userInfo resultTarget:eventTarget]);
	}
}

- (OCProgress *)_scheduleShareUpdateWithUserInfo:(NSDictionary *)inUserInfo resultTarget:(OCEventTarget *)eventTarget
{
	NSMutableDictionary *userInfo = [inUserInfo mutableCopy];
	OCShareID shareID = userInfo[@"shareID"];
	NSMutableDictionary<NSString *,NSString *> *changedValuesByPropertyNames = [userInfo[@"updateProperties"] mutableCopy];
	NSString *updateProperty = nil;
	NSString *updateValue = nil;
	OCProgress *requestProgress = nil;

	if (changedValuesByPropertyNames.count > 0)
	{
		updateProperty = changedValuesByPropertyNames.allKeys.firstObject;
		updateValue = changedValuesByPropertyNames[updateProperty];
	}

	if ((updateProperty!=nil) && (updateValue!=nil))
	{
		// Remove from update dict
		[changedValuesByPropertyNames removeObjectForKey:updateProperty];
		userInfo[@"updateProperties"] = changedValuesByPropertyNames;
		userInfo[@"lastChangedProperty"] = updateProperty;
		userInfo[@"moreUpdatesPending"] = @(changedValuesByPropertyNames.count > 0);

		// Compose and send request
		OCHTTPRequest *request;

		request = [OCHTTPRequest requestWithURL:[[self URLForEndpoint:OCConnectionEndpointIDShares options:nil] URLByAppendingPathComponent:shareID]];
		request.method = OCHTTPMethodPUT;
		request.requiredSignals = self.propFindSignals;

		[request setValue:updateValue forParameter:updateProperty];

		request.resultHandlerAction = @selector(_handleUpdateShareResult:error:);
		request.eventTarget = eventTarget;
		request.userInfo = userInfo;

		request.forceCertificateDecisionDelegation = YES;

		[self.commandPipeline enqueueRequest:request forPartitionID:self.partitionID];

		requestProgress = request.progress;
		requestProgress.progress.eventType = OCEventTypeUpdateShare;
		requestProgress.progress.localizedDescription = OCLocalized(@"Updating share…");
	}
	else
	{
		[eventTarget handleError:OCErrorWithDescription(OCErrorInsufficientParameters, @"Nothing provided to update") type:OCEventTypeUpdateShare uuid:nil sender:self];
	}

	return (requestProgress);
}

- (void)_handleUpdateShareResult:(OCHTTPRequest *)request error:(NSError *)error
{
	OCEvent *event;

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeUpdateShare uuid:request.identifier attributes:nil]) != nil)
	{
		if ((request.error != nil) && ![request.error.domain isEqual:OCHTTPStatusErrorDomain])
		{
			event.error = request.error;
		}
		else
		{
			NSArray <OCShare *> *shares = nil;
			NSError *parseError = nil;

			shares = [self _parseSharesResponse:request.httpResponse data:request.httpResponse.bodyData error:&parseError status:NULL statusErrorMapper:^NSError *(OCSharingResponseStatus *status) {
				NSError *error = nil;

				switch (status.statusCode.integerValue)
				{
					case 100:
					case OCHTTPStatusCodeOK: // 200
						// Successful
					break;

					case OCHTTPStatusCodeBAD_REQUEST: // 400
						// Wrong or no update parameter given
						error = OCErrorWithDescription(OCErrorInsufficientParameters, status.message);
					break;

					case OCHTTPStatusCodeFORBIDDEN: // 403
						// Public upload disabled by the admin
						error = OCErrorWithDescription(OCErrorSharePublicUploadDisabled, status.message);
					break;

					case OCHTTPStatusCodeNOT_FOUND: // 404
						// Share couldn't be updated
						error = OCErrorWithDescription(OCErrorShareNotFound, status.message);
					break;

					default:
						// Unknown error
						error = status.error;
					break;
				}

				return (error);
			}];

			if (parseError == nil)
			{
				NSDictionary *userInfo = request.userInfo;
				OCEventTarget *eventTarget = request.eventTarget;
				BOOL moreUpdatesPending = ((NSNumber *)userInfo[@"moreUpdatesPending"]).boolValue;

				if (moreUpdatesPending)
				{
					event = nil;
					[self _scheduleShareUpdateWithUserInfo:userInfo resultTarget:eventTarget];
				}
				else
				{
					event.result = shares.firstObject;
				}
			}
			else
			{
				event.error = parseError;
			}
		}
	}

	if (event != nil)
	{
		[request.eventTarget handleEvent:event sender:self];
	}
}

- (nullable OCProgress *)deleteShare:(OCShare *)share resultTarget:(OCEventTarget *)eventTarget
{
	OCHTTPRequest *request;
	OCProgress *requestProgress = nil;

	if (share.type == OCShareTypeRemote)
	{
		// Shares of type "remote" need to be declined to be deleted
		if (share.owner.isRemote)
		{
			// But only if the owner is remote (otherwise the share was created by the logged in user)
			return ([self makeDecisionOnShare:share accept:NO resultTarget:eventTarget]);
		}
	}

	if (share.identifier == nil)
	{
		[eventTarget handleError:OCError(OCErrorInsufficientParameters) type:OCEventTypeDeleteShare uuid:nil sender:self];
		return (nil);
	}

	request = [OCHTTPRequest requestWithURL:[[self URLForEndpoint:OCConnectionEndpointIDShares options:nil] URLByAppendingPathComponent:share.identifier]];
	request.method = OCHTTPMethodDELETE;
	request.requiredSignals = self.propFindSignals;
	request.forceCertificateDecisionDelegation = YES;

	request.resultHandlerAction = @selector(_handleDeleteShareResult:error:);
	request.eventTarget = eventTarget;

	[self.commandPipeline enqueueRequest:request forPartitionID:self.partitionID];

	requestProgress = request.progress;
	requestProgress.progress.eventType = OCEventTypeDeleteShare;
	requestProgress.progress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Deleting share for %@…"), share.itemPath.lastPathComponent];

	return (requestProgress);
}

- (void)_handleDeleteShareResult:(OCHTTPRequest *)request error:(NSError *)error
{
	OCEvent *event;

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeDeleteShare uuid:request.identifier attributes:nil]) != nil)
	{
		if ((request.error != nil) && ![request.error.domain isEqual:OCHTTPStatusErrorDomain])
		{
			event.error = request.error;
		}
		else
		{
			[self _parseSharesResponse:request.httpResponse data:request.httpResponse.bodyData error:&error status:NULL statusErrorMapper:^NSError *(OCSharingResponseStatus *status) {
				NSError *error = nil;

				switch (status.statusCode.integerValue)
				{
					case 100:
					case 200:
						// Successful
					break;

					case 404:
						// Share couldn't be deleted
						error = OCErrorWithDescription(OCErrorShareNotFound, status.message);
					break;

					default:
						// Unknown error
						error = status.error;
					break;
				}

				return (error);
			}];

			event.error = error;
		}
	}

	if (event != nil)
	{
		[request.eventTarget handleEvent:event sender:self];
	}
}

#pragma mark - Federated share management
- (nullable OCProgress *)makeDecisionOnShare:(OCShare *)share accept:(BOOL)accept resultTarget:(OCEventTarget *)eventTarget
{
	OCHTTPRequest *request;
	OCProgress *requestProgress = nil;
	NSURL *endpointURL = nil;

	if (share.identifier == nil)
	{
		[eventTarget handleError:OCError(OCErrorInsufficientParameters) type:OCEventTypeDecideOnShare uuid:nil sender:self];
		return (nil);
	}

	switch (share.type)
	{
		case OCShareTypeUserShare:
		case OCShareTypeGroupShare:
			endpointURL = [self URLForEndpoint:OCConnectionEndpointIDShares options:nil];
		break;

		case OCShareTypeRemote:
			endpointURL = [self URLForEndpoint:OCConnectionEndpointIDRemoteShares options:nil];
		break;

		default: break;
	}

	if (endpointURL == nil)
	{
		[eventTarget handleError:OCError(OCErrorInsufficientParameters) type:OCEventTypeDecideOnShare uuid:nil sender:self];
		return (nil);
	}

	request = [OCHTTPRequest requestWithURL:[[endpointURL URLByAppendingPathComponent:@"pending"] URLByAppendingPathComponent:share.identifier]];
	request.method = (accept ? OCHTTPMethodPOST : OCHTTPMethodDELETE);
	request.requiredSignals = self.propFindSignals;

	[request setValue:share.identifier forParameter:@"share_id"];

	request.resultHandlerAction = @selector(_handleMakeDecisionOnShareResult:error:);
	request.eventTarget = eventTarget;

	request.forceCertificateDecisionDelegation = YES;

	[self.commandPipeline enqueueRequest:request forPartitionID:self.partitionID];

	requestProgress = request.progress;
	requestProgress.progress.eventType = OCEventTypeDecideOnShare;
	requestProgress.progress.localizedDescription = (accept ? OCLocalized(@"Accepting share…") : OCLocalized(@"Rejecting share…"));

	return (requestProgress);
}

- (void)_handleMakeDecisionOnShareResult:(OCHTTPRequest *)request error:(NSError *)error
{
	OCEvent *event;

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeDecideOnShare uuid:request.identifier attributes:nil]) != nil)
	{
		if ((request.error != nil) && ![request.error.domain isEqual:OCHTTPStatusErrorDomain])
		{
			event.error = request.error;
		}
		else
		{
			[self _parseSharesResponse:request.httpResponse data:request.httpResponse.bodyData error:&error status:NULL statusErrorMapper:^NSError *(OCSharingResponseStatus *status) {
				NSError *error = nil;

				switch (status.statusCode.integerValue)
				{
					case 100:
					case 200:
						// Successful
					break;

					case 404:
						// Share doesn’t exist
						error = OCErrorWithDescription(OCErrorShareNotFound, status.message);
					break;

					default:
						// Unknown error
						error = status.error;
					break;
				}

				return (error);
			}];

			event.error = error;
		}
	}

	if (event != nil)
	{
		[request.eventTarget handleEvent:event sender:self];
	}
}

#pragma mark - Private Link
- (nullable NSProgress *)retrievePrivateLinkForItem:(OCItem *)item completionHandler:(void(^)(NSError * _Nullable error, NSURL * _Nullable privateLink))completionHandler
{
	if (item.privateLink != nil)
	{
		// Private link already known for item
		completionHandler(nil, item.privateLink);
		return ([NSProgress indeterminateProgress]);
	}
	else
	{
		// Private link needs to be retrieved from server
		NSProgress *progress = nil;
		NSURL *endpointURL = [self URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:nil];
		OCHTTPDAVRequest *davRequest;

		davRequest = [OCHTTPDAVRequest propfindRequestWithURL:[endpointURL URLByAppendingPathComponent:item.path] depth:0];
		davRequest.requiredSignals = self.propFindSignals;

		[davRequest.xmlRequestPropAttribute addChildren:@[
			[OCXMLNode elementWithName:@"oc:privatelink"]
		]];

		progress = [self sendRequest:davRequest ephermalCompletionHandler:^(OCHTTPRequest * _Nonnull request, OCHTTPResponse * _Nullable response, NSError * _Nullable error) {
			if ((error == nil) && (response.status.isSuccess))
			{
				NSArray <NSError *> *errors = nil;
				NSArray <OCItem *> *items = nil;

				if ((items = [((OCHTTPDAVRequest *)request) responseItemsForBasePath:endpointURL.path reuseUsersByID:self->_usersByUserID withErrors:&errors]) != nil)
				{
					NSURL *privateLink;

					if ((privateLink = items.firstObject.privateLink) != nil)
					{
						item.privateLink = privateLink;

						completionHandler(nil, privateLink);
						return;
					}
				}
			}
			else
			{
				if (error == nil)
				{
					error = response.bodyParsedAsDAVError;
				}

				if (error == nil)
				{
					error = response.status.error;
				}
			}

			completionHandler(error, nil);
		}];

		return (progress);
	}
}

- (nullable NSProgress *)retrievePathForPrivateLink:(NSURL *)privateLink completionHandler:(void(^)(NSError * _Nullable error, NSString * _Nullable path))completionHandler
{
	NSProgress *progress = nil;
	OCPrivateLinkFileID privateFileID = nil;

	if ((privateFileID = privateLink.privateLinkFileID) != nil)
	{
		OCHTTPDAVRequest *davRequest;
		NSURL *endpointURL = [self URLForEndpoint:OCConnectionEndpointIDWebDAVMeta options:nil];

		davRequest = [OCHTTPDAVRequest propfindRequestWithURL:[endpointURL URLByAppendingPathComponent:privateFileID] depth:0];
		davRequest.requiredSignals = self.propFindSignals;

		[davRequest.xmlRequestPropAttribute addChildren:@[
			[OCXMLNode elementWithName:@"oc:meta-path-for-user"],
			// [OCXMLNode elementWithName:@"D:resourcetype"] // The value returned for D:resourcetype is not correct. OC server will return d:collection for files, too.
		]];

		__weak OCConnection *weakSelf = self;

		progress = [self sendRequest:davRequest ephermalCompletionHandler:^(OCHTTPRequest * _Nonnull request, OCHTTPResponse * _Nullable response, NSError * _Nullable error) {
			OCConnection *strongSelf = weakSelf;

			if (strongSelf == nil)
			{
				// End if connection object is gone
				error = OCError(OCErrorInternal);
			}

			if ((error == nil) && (response.status.isSuccess))
			{
				NSArray <NSError *> *errors = nil;
				NSArray <OCItem *> *items = nil;

				if ((items = [((OCHTTPDAVRequest *)request) responseItemsForBasePath:endpointURL.path reuseUsersByID:self->_usersByUserID withErrors:&errors]) != nil)
				{
					NSString *path;

					if ((path = items.firstObject.path) != nil)
					{
						// OC Server will return "/Documents" for the documents folder => make sure to normalize the path to follow OCPath conventions in that case
						// The value of D:resourcetype is not correct when requested with the same (resolution) request. OC server will return d:collection for files, too.

						// Perform standard depth 0 PROPFIND on path to determine type
						[strongSelf retrieveItemListAtPath:path depth:0 options:@{ OCConnectionOptionIsNonCriticalKey : @(YES) } completionHandler:^(NSError * _Nullable error, NSArray<OCItem *> * _Nullable items) {
							OCPath normalizedPath = nil;

							if (error == nil)
							{
								OCItem *item;

								if ((item = items.firstObject) != nil)
								{
									switch (item.type)
									{
										case OCItemTypeFile:
											normalizedPath = path.normalizedFilePath;
										break;

										case OCItemTypeCollection:
											normalizedPath = path.normalizedDirectoryPath;
										break;

										default:
											normalizedPath = path;
										break;
									}
								}
							}

							completionHandler(error, normalizedPath);
						}];

						return;
					}
				}

				error = OCError(OCErrorPrivateLinkResolutionFailed);
			}
			else
			{
				if (error == nil)
				{
					error = response.bodyParsedAsDAVError;
				}

				if (error == nil)
				{
					error = response.status.error;
				}
			}

			completionHandler(error, nil);
		}];
	}
	else
	{
		// Private File ID couldn't be determined
		completionHandler(OCError(OCErrorPrivateLinkInvalidFormat), nil);
	}

	return (progress);
}

@end
