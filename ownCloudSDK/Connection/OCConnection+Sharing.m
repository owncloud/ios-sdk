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

@interface OCSharingResponseStatus : NSObject <OCXMLObjectCreation>

@property(strong) NSString *status;
@property(strong) NSNumber *statusCode;

@end

@implementation OCSharingResponseStatus

+ (NSString *)xmlElementNameForObjectCreation {
	return (@"meta");
}

+ (instancetype)instanceFromNode:(OCXMLParserNode *)metaNode xmlParser:(OCXMLParser *)xmlParser {
	OCSharingResponseStatus *responseStatus = [self new];

	responseStatus.status = metaNode.keyValues[@"status"];

	if (metaNode.keyValues[@"statuscode"] != nil)
	{
		responseStatus.statusCode = @(((NSString *)metaNode.keyValues[@"statuscode"]).integerValue);
	}

	xmlParser.userInfo[@"sharingResponseStatus"] = responseStatus;

	return (nil);
}

@end

@implementation OCConnection (Sharing)

#pragma mark - Retrieval
- (NSArray<OCShare *> *)_parseSharesResponseData:(NSData *)responseData error:(NSError **)outError
{
	OCXMLParser *parser;

	if ((parser = [[OCXMLParser alloc] initWithData:responseData]) != nil)
	{
		[parser addObjectCreationClasses:@[ [OCShare class], [OCSharingResponseStatus class] ]];

		if ([parser parse])
		{
			// OCLogDebug(@"Parsed objects: %@", parser.parsedObjects);

			@synchronized(self)
			{
				OCSharingResponseStatus *status = parser.userInfo[@"sharingResponseStatus"];
			}
		}

		return (parser.parsedObjects);
	}

	return (nil);
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
		NSArray <OCShare *> *shares;

		if (error == nil)
		{
			shares = [self _parseSharesResponseData:response.bodyData error:&error];
		}

		completionHandler(error, shares);
	}];

	return (progress);
}

@end
