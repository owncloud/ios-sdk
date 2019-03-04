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

@interface OCSharingResponseStatus : NSObject <OCXMLObjectCreation>

@property(strong) NSString *status;
@property(strong) NSNumber *statusCode;

@property(strong) NSString *message;

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

	if (response != nil)
	{
		if (!response.status.isSuccess)
		{
			error = response.status.error;
		}
	}

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

	if (outError != NULL)
	{
		*outError = error;
	}

	return (parser.parsedObjects);
}

- (nullable NSProgress *)retrieveSharesWithScope:(OCConnectionShareScope)scope forItem:(nullable OCItem *)item options:(nullable NSDictionary *)options completionHandler:(OCConnectionShareRetrievalCompletionHandler)completionHandler
{
	OCHTTPRequest *request;
	NSProgress *progress = nil;
	NSURL *url = [self URLForEndpoint:OCConnectionEndpointIDShares options:nil];

	request = [OCHTTPRequest new];
	request.requiredSignals = [NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable];

	switch (scope)
	{
		case OCConnectionShareScopeItem:
		case OCConnectionShareScopeItemWithReshares:
		case OCConnectionShareScopeSubItems:
		break;

		default:
			if (item != nil)
			{
				OCLogWarning(@"item=%@ ignored for retrieval of shares with scope=%d", item, scope);
			}
		break;
	}

	switch (scope)
	{
		case OCConnectionShareScopeSharedByUser:
			// No options to set
		break;

		case OCConnectionShareScopeSharedWithUser:
			[request setValue:@"true" forParameter:@"shared_with_me"];
		break;

		case OCConnectionShareScopePendingCloudShares:
			url = [[self URLForEndpoint:OCConnectionEndpointIDRemoteShares options:nil] URLByAppendingPathComponent:@"pending"];
		break;

		case OCConnectionShareScopeAcceptedCloudShares:
			url = [self URLForEndpoint:OCConnectionEndpointIDRemoteShares options:nil];
		break;

		case OCConnectionShareScopeItem:
		case OCConnectionShareScopeItemWithReshares:
		case OCConnectionShareScopeSubItems:
			if (item == nil)
			{
				OCLogError(@"item required for retrieval of shares with scope=%d", scope);

				if (completionHandler != nil)
				{
					completionHandler(OCError(OCErrorInsufficientParameters), nil);
				}

				return (nil);
			}

			[request setValue:item.path forParameter:@"path"];

			if (scope == OCConnectionShareScopeItemWithReshares)
			{
				[request setValue:@"true" forParameter:@"reshares"];
			}

			if (scope == OCConnectionShareScopeSubItems)
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
						// Successful
					break;

					case 400:
						// Not a directory (fetching shares for directory)
						error = OCError(OCErrorShareItemNotADirectory);
					break;

					case 404:
						switch (scope)
						{
							case OCConnectionShareScopeSharedByUser:
							case OCConnectionShareScopeSharedWithUser:
								// Couldn't fetch shares (fetching all shares)
								error = OCError(OCErrorShareUnavailable);
							break;

							case OCConnectionShareScopeItem:
							case OCConnectionShareScopeItemWithReshares:
								// File doesn't exist (fetching shares for file)
								error = OCError(OCErrorShareItemNotFound);
							break;

							default:
								// Unknown error
								error = OCErrorWithInfo(OCErrorUnknown, @{
									@"statusCode" : status.statusCode
								});
							break;
						}
					break;

					case 997:
						// Unauthorized
						error = OCError(OCErrorShareUnauthorized);
					break;

					default:
						// Unknown error
						error = OCErrorWithInfo(OCErrorUnknown, status.message != nil ? status.message : @"Unknown server error without description.");
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
	request.requiredSignals = [NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable];

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
							// Successful
						break;

						case 404:
							// Share does not exist
							error = OCError(OCErrorShareNotFound);
						break;

						default:
							// Unknown error
							error = OCErrorWithInfo(OCErrorUnknown, status.message != nil ? status.message : @"Unknown server error without description.");
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
- (nullable OCProgress *)createShare:(OCShare *)share options:(nullable NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget
{
	OCHTTPRequest *request;
	OCProgress *requestProgress = nil;

	request = [OCHTTPRequest requestWithURL:[self URLForEndpoint:OCConnectionEndpointIDShares options:nil]];
	request.method = OCHTTPMethodPOST;
	request.requiredSignals = [NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable];

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

	[self.commandPipeline enqueueRequest:request forPartitionID:self.partitionID];

	requestProgress = request.progress;
	requestProgress.progress.eventType = OCEventTypeCreateShare;
	requestProgress.progress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Creating share for %@…"), share.itemPath.lastPathComponent];

	return (requestProgress);
}

- (void)_handleCreateShareResult:(OCHTTPRequest *)request error:(NSError *)error
{
	OCEvent *event;

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeCreateShare attributes:nil]) != nil)
	{
		if (request.error != nil)
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
						// Successful
					break;

					case 400:
						// Not a directory (fetching shares for directory)
						error = OCError(OCErrorShareUnknownType);
					break;

					case 403:
						// Public upload was disabled by the admin
						error = OCError(OCErrorSharePublicUploadDisabled);
					break;

					case 404:
						// File or folder couldn’t be shared
						error = OCError(OCErrorShareItemNotFound);
					break;

					default:
						// Unknown error
						error = OCErrorWithInfo(OCErrorUnknown, status.message != nil ? status.message : @"Unknown server error without description.");
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
	return (nil);
}

- (void)_handleUpdateShareResult:(OCHTTPRequest *)request error:(NSError *)error
{
}

- (nullable OCProgress *)deleteShare:(OCShare *)share resultTarget:(OCEventTarget *)eventTarget
{
	return (nil);
}

- (void)_handleDeleteShareResult:(OCHTTPRequest *)request error:(NSError *)error
{
}

#pragma mark - Federated share management
- (nullable OCProgress *)makeDecisionOnShare:(OCShare *)share accept:(BOOL)accept resultTarget:(OCEventTarget *)eventTarget
{
	return (nil);
}

- (void)_handleMakeDecisionOnShareResult:(OCHTTPRequest *)request error:(NSError *)error
{
}

@end
