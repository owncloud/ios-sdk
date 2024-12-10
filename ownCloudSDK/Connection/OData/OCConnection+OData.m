//
//  OCConnection+OData.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 10.02.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCConnection+OData.h"
#import "GAODataError.h"
#import "NSError+OCError.h"

@implementation OCConnection (OData)

- (void)decodeODataResponse:(OCHTTPResponse *)response error:(nullable NSError *)error entityClass:(nullable Class)entityClass completionHandler:(OCConnectionODataRequestCompletionHandler)completionHandler
{
	NSDictionary <NSString *, id> *jsonDictionary = nil;
	NSError *returnError = error;
	id returnResult = nil;

	if (error == nil)
	{
		NSError *jsonError = nil;

		if ((jsonDictionary = [response bodyConvertedDictionaryFromJSONWithError:&jsonError]) != nil)
		{
			if (jsonDictionary[@"error"] != nil)
			{
				NSError *decodeError = nil;

				GAODataError *dataError = [jsonDictionary objectForKey:@"error" ofClass:GAODataError.class inCollection:Nil required:NO context:nil error:&decodeError];
				returnError = dataError.nativeError;
			}
			else if ((jsonDictionary[@"value"] != nil) && (entityClass != nil))
			{
				if ([jsonDictionary[@"value"] isKindOfClass:NSArray.class])
				{
					returnResult = [jsonDictionary objectForKey:@"value" ofClass:entityClass inCollection:NSArray.class required:NO context:nil error:&returnError];
				}
				else
				{
					returnResult = [jsonDictionary objectForKey:@"value" ofClass:entityClass inCollection:Nil required:NO context:nil error:&returnError];
				}
			}
			else if (entityClass != nil)
			{
				returnResult = [NSDictionary object:jsonDictionary key:nil ofClass:entityClass inCollection:Nil required:YES context:nil error:&returnError];
			}
			else
			{
				returnError = OCError(OCErrorResponseUnknownFormat);
			}
		}
		else if (jsonError != nil)
		{
			returnError = jsonError;
		}
	}

	OCLogDebug(@"OData response: returnResult=%@, error=%@, json: %@", returnResult, returnError, jsonDictionary);

	completionHandler(returnError, returnResult);
}

- (NSProgress *)requestODataAtURL:(NSURL *)url requireSignals:(nullable NSSet<OCConnectionSignalID> *)requiredSignals selectEntityID:(nullable OCODataEntityID)selectEntityID selectProperties:(nullable NSArray<OCODataProperty> *)selectProperties filterString:(nullable OCODataFilterString)filterString parameters:(nullable NSDictionary<NSString *,NSString *> *)additionalParameters entityClass:(Class)entityClass completionHandler:(OCConnectionODataRequestCompletionHandler)completionHandler
{
	OCHTTPRequest *request;
	NSProgress *progress = nil;
	NSString *urlSuffix = nil;
	OCHTTPRequestParameters requestParameters = [NSMutableDictionary new];

	// Select entity: "…/endpoint('entityID')"
	if ((selectEntityID != nil) && (selectEntityID.length > 0))
	{
		// urlSuffix = [NSString stringWithFormat:@"('%@')", selectEntityID]; // as per OData specification
		urlSuffix = [NSString stringWithFormat:@"/%@", selectEntityID]; // practically supported
	}

	if (urlSuffix != nil)
	{
		url = [NSURL URLWithString:[url.absoluteString stringByAppendingString:urlSuffix]];
	}

	// Select properties: "…/endpoint?$select=PropertyName1, PropertyName2"
	if ((selectProperties != nil) && (selectProperties.count > 0))
	{
		requestParameters[@"$select"] = [selectProperties componentsJoinedByString:@", "];
	}

	// Filter string: "…/endpoint?$filter=FirstName eq 'Scott'"
	if (filterString.length > 0)
	{
		requestParameters[@"$filter"] = filterString;
	}

	// Additional parameters
	if (additionalParameters.count > 0)
	{
		[requestParameters addEntriesFromDictionary:additionalParameters];
	}

	// Compose HTTP request
	request = [OCHTTPRequest requestWithURL:url];
	request.requiredSignals = requiredSignals; // self.actionSignals;
	if (requestParameters.count > 0)
	{
		request.parameters = requestParameters;
	}

	progress = [self sendRequest:request ephermalCompletionHandler:^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
		[self decodeODataResponse:response error:error entityClass:entityClass completionHandler:completionHandler];
	}];

	return (progress);
}

- (nullable NSProgress *)createODataObject:(id<GAGraphObject>)object atURL:(NSURL *)url requireSignals:(nullable NSSet<OCConnectionSignalID> *)requiredSignals parameters:(nullable NSDictionary<NSString *,NSString *> *)additionalParameters responseEntityClass:(nullable Class)responseEntityClass completionHandler:(OCConnectionODataRequestCompletionHandler)completionHandler
{
	NSProgress *progress = nil;
	NSError *error = nil;
	GAGraphStruct graphStruct = nil;
	NSData *postData = nil;

	// Encode object to JSON
	graphStruct = [object encodeToGraphStructWithContext:nil error:&error];
	if (error != nil) {
		completionHandler(error, nil);
		return(nil);
	}
	if (graphStruct != nil)
	{
		postData = [NSJSONSerialization dataWithJSONObject:graphStruct options:0 error:&error];
		if (error != nil) {
			completionHandler(error, nil);
			return(nil);
		}
	}

	OCHTTPRequest *request;

	request = [OCHTTPRequest requestWithURL:url];
	request.method = OCHTTPMethodPOST;
	request.requiredSignals = requiredSignals; // self.actionSignals;
	if (additionalParameters.count > 0)
	{
		request.parameters = [additionalParameters mutableCopy];
	}
	request.bodyData = postData;

	progress = [self sendRequest:request ephermalCompletionHandler:^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
		[self decodeODataResponse:response error:error entityClass:((responseEntityClass != nil) ? responseEntityClass : object.class) completionHandler:completionHandler];
	}];

	return (progress);
}

@end
