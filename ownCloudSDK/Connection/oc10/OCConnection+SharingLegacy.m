//
//  OCConnection+SharingLegacy.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.12.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCConnection+SharingLegacy.h"
#import "NSDate+OCDateParser.h"
#import "NSProgress+OCEvent.h"
#import "OCMacros.h"
#import "NSError+OCNetworkFailure.h"
#import "NSError+OCError.h"
#import "OCXMLParserNode.h"

// OC 10
#if OC_LEGACY_SUPPORT

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

@implementation OCConnection (SharingLegacy)

- (NSArray<OCShare *> *)_parseSharesResponse:(OCHTTPResponse *)response data:(NSData *)responseData category:(OCShareCategory)shareCategory error:(NSError **)outError status:(OCSharingResponseStatus **)outStatus statusErrorMapper:(NSError*(^)(OCSharingResponseStatus *status))statusErrorMapper
{
	OCXMLParser *parser = nil;
	NSError *error;

	if (error == nil)
	{
		if ((parser = [[OCXMLParser alloc] initWithData:responseData]) != nil)
		{
			parser.options[@"_shareCategory"] = @(shareCategory);
			[parser addObjectCreationClasses:@[ OCShare.class, OCShareSingle.class, OCSharingResponseStatus.class ]];

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

// MARK: - Create share (legacy)
- (nullable OCProgress *)legacyCreateShare:(OCShare *)share options:(nullable OCShareOptions)options resultTarget:(OCEventTarget *)eventTarget
{
	OCHTTPRequest *request;
	OCProgress *requestProgress = nil;

	request = [OCHTTPRequest requestWithURL:[self URLForEndpoint:OCConnectionEndpointIDShares options:@{
		OCConnectionOptionDriveID : OCDriveIDWrap(share.itemLocation.driveID)
	}]];
	request.method = OCHTTPMethodPOST;
	request.requiredSignals = self.propFindSignals;

	if (share.name != nil)
	{
		[request setValue:share.name forParameter:@"name"];
	}

	[request setValue:[NSString stringWithFormat:@"%ld", share.type] forParameter:@"shareType"];

	[request setValue:share.itemLocation.path forParameter:@"path"];

	[request setValue:[NSString stringWithFormat:@"%ld", share.permissions] forParameter:@"permissions"];

	if ((share.itemFileID != nil) && self.useDriveAPI)
	{
		// Add the file ID to allow the server to determine the item's location (path, of course, isn't sufficient there)
		[request setValue:share.itemFileID forParameter:@"space_ref"];
	}

	if (share.expirationDate != nil)
	{
		[request setValue:(self.useDriveAPI ? share.expirationDate.compactISO8601String : share.expirationDate.compactUTCStringDateOnly) forParameter:@"expireDate"];
	}

	if (share.type != OCShareTypeLink)
	{
		[request setValue:share.recipient.identifier forParameter:@"shareWith"];
	}

	if (share.password != nil)
	{
		[request setValue:share.password forParameter:@"password"];
	}

	request.resultHandlerAction = @selector(_legacyHandleCreateShareResult:error:);
	request.eventTarget = eventTarget;

	request.forceCertificateDecisionDelegation = YES;

	[self.commandPipeline enqueueRequest:request forPartitionID:self.partitionID];

	requestProgress = request.progress;
	requestProgress.progress.eventType = OCEventTypeCreateShare;
	requestProgress.progress.localizedDescription = [NSString stringWithFormat:OCLocalizedString(@"Creating share for %@…",nil), share.itemLocation.path.lastPathComponent];

	return (requestProgress);
}

- (void)_legacyHandleCreateShareResult:(OCHTTPRequest *)request error:(NSError *)error
{
	OCEvent *event;

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeCreateShare uuid:request.identifier attributes:nil]) != nil)
	{
		if (error.isNetworkFailureError)
		{
			event.error = OCErrorWithDescriptionFromError(OCErrorNotAvailableOffline, OCLocalizedString(@"Sharing requires an active connection.",nil), error);
		}
		else if ((request.error != nil) && ![request.error.domain isEqual:OCHTTPStatusErrorDomain])
		{
			event.error = request.error;
		}
		else
		{
			NSArray <OCShare *> *shares = nil;

			shares = [self _parseSharesResponse:request.httpResponse data:request.httpResponse.bodyData category:OCShareCategoryByMe error:&error status:NULL statusErrorMapper:^NSError *(OCSharingResponseStatus *status) {
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

// MARK: - Update share (legacy)
- (nullable OCProgress *)legacyUpdateShare:(OCShare *)share afterPerformingChanges:(void(^)(OCShare *share))performChanges resultTarget:(OCEventTarget *)eventTarget
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
		NSString *expirationDate = @"";

		if (share.expirationDate != nil)
		{
			if (self.useDriveAPI)
			{
				expirationDate = share.expirationDate.compactISO8601String;
			}
			else
			{
				expirationDate = share.expirationDate.compactUTCStringDateOnly;
			}
		}

		changedValuesByPropertyNames[@"expireDate"] = expirationDate;
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
		requestProgress.progress.localizedDescription = OCLocalizedString(@"Updating share…",nil);
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
		if (error.isNetworkFailureError)
		{
			event.error = OCErrorWithDescriptionFromError(OCErrorNotAvailableOffline, OCLocalizedString(@"Sharing requires an active connection.",nil), error);
		}
		else if ((request.error != nil) && ![request.error.domain isEqual:OCHTTPStatusErrorDomain])
		{
			event.error = request.error;
		}
		else
		{
			NSArray <OCShare *> *shares = nil;
			NSError *parseError = nil;

			shares = [self _parseSharesResponse:request.httpResponse data:request.httpResponse.bodyData category:OCShareCategoryByMe error:&parseError status:NULL statusErrorMapper:^NSError *(OCSharingResponseStatus *status) {
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

@end

#endif /* OC_LEGACY_SUPPORT */
