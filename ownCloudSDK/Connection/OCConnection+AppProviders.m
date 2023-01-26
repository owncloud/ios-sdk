//
//  OCConnection+AppProviders.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.09.22.
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

#import "OCConnection.h"
#import "NSError+OCError.h"
#import "NSError+OCISError.h"
#import "OCMacros.h"
#import "OCAppProviderApp.h"
#import "NSDictionary+OCFormEncoding.h"
#import "OCLocale+SystemLanguage.h"

@implementation OCConnection (AppProviders)

#pragma mark - App List
- (nullable NSProgress *)retrieveAppProviderListWithCompletionHandler:(void(^)(NSError * _Nullable error, OCAppProvider * _Nullable appProvider))completionHandler
{
	OCAppProvider *appProvider;
	NSProgress *progress = nil;

	if ((appProvider = self.capabilities.latestSupportedAppProvider) != nil)
	{
		NSURL *appListURL = [self URLForEndpoint:OCConnectionEndpointIDAppProviderList options:nil];
		OCHTTPRequest *request;

		if ((request = [OCHTTPRequest requestWithURL:appListURL]) != nil)
		{
			request.requiredSignals = [NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable];

			progress = [self sendRequest:request ephermalCompletionHandler:^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
				NSData *responseBody = response.bodyData;

				if ((error == nil) && response.status.isSuccess && (responseBody!=nil))
				{
					NSDictionary<NSString *, id> *rawJSON;

					if ((rawJSON = [NSJSONSerialization JSONObjectWithData:responseBody options:0 error:&error]) != nil)
					{
						OCAppProviderAppList appList;

						if ((appList = OCTypedCast(rawJSON[@"mime-types"], NSArray)) != nil)
						{
							appProvider.appList = appList;
						}
						else
						{
							error = OCError(OCErrorResponseUnknownFormat);
						}
					}
				}
				else
				{
					if (error == nil)
					{
						error = response.status.error;
					}
				}

				completionHandler(error, (error == nil) ? appProvider : nil);
			}];
		}
		else
		{
			completionHandler(OCError(OCErrorInternal), nil);
		}
	}
	else
	{
		completionHandler(OCError(OCErrorFeatureNotSupportedByServer), nil);
	}

	return (progress);
}

#pragma mark - Create App Document
- (nullable NSProgress *)createAppFileOfType:(OCAppProviderFileType *)appType in:(OCItem *)parentDirectoryItem withName:(NSString *)fileName completionHandler:(nonnull void (^)(NSError * _Nullable, OCFileID _Nullable, OCItem * _Nullable))completionHandler
{
	NSProgress *progress = nil;
	NSURL *appListURL = [self URLForEndpoint:OCConnectionEndpointIDAppProviderNew options:nil];
	OCHTTPRequest *request;

	if ((request = [OCHTTPRequest requestWithURL:appListURL]) != nil)
	{
		request.method = OCHTTPMethodPOST;
		request.requiredSignals = [NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable];
		request.parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:
			parentDirectoryItem.fileID,	@"parent_container_id",
			fileName,			@"filename",
		nil];

		progress = [self sendRequest:request ephermalCompletionHandler:^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
			NSData *responseBody = response.bodyData;
			OCFileID fileID = nil;

			if ((error == nil) && response.status.isSuccess && (responseBody!=nil))
			{
				id rawJSON;

				if ((rawJSON = [NSJSONSerialization JSONObjectWithData:responseBody options:0 error:&error]) != nil)
				{
					NSDictionary<NSString *, id> *jsonResponse;

					if (!(((jsonResponse = OCTypedCast(rawJSON, NSDictionary)) != nil) &&
					     ((fileID = OCTypedCast(jsonResponse[@"file_id"], NSString)) != nil)))
					{
						error = OCError(OCErrorResponseUnknownFormat);
					}
				}
			}
			else
			{
				if (error == nil)
				{
					error = response.status.error;
				}
			}

			completionHandler(error, fileID, nil);
		}];
	}
	else
	{
		completionHandler(OCError(OCErrorInternal), nil, nil);
	}

	return (progress);
}

#pragma mark - Open
- (nullable NSProgress *)openInApp:(OCItem *)item withApp:(nullable OCAppProviderApp *)app viewMode:(nullable OCAppProviderViewMode)viewMode completionHandler:(void(^)(NSError * _Nullable error, NSURL * _Nullable appURL, OCHTTPMethod _Nullable httpMethod, OCHTTPHeaderFields _Nullable headerFields, OCHTTPRequestParameters _Nullable parameters, NSMutableURLRequest * _Nullable urlRequest))completionHandler
{
	NSProgress *progress = nil;
	NSURL *appListURL = [self URLForEndpoint:OCConnectionEndpointIDAppProviderOpen options:nil];
	OCHTTPRequest *request;

	if ((request = [OCHTTPRequest requestWithURL:appListURL]) != nil)
	{
		OCHTTPStaticHeaderFields staticHeaderFields = self.staticHeaderFields;

		request.method = OCHTTPMethodPOST;
		request.requiredSignals = [NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable];
		request.parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:
			item.fileID,	@"file_id",
			app.name,	@"app_name",
		nil];

		NSString *primaryLanguage = OCLocale.sharedLocale.primaryUserLanguage;

		if (primaryLanguage != nil)
		{
			[request addParameters:@{
				@"lang" : primaryLanguage
			}];
		}

		if (viewMode != nil)
		{
			[request addParameters:@{
				@"view_mode" : viewMode
			}];
		}

		progress = [self sendRequest:request ephermalCompletionHandler:^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
			NSData *responseBody = response.bodyData;
			NSURL *appURL = nil;
			OCHTTPMethod httpMethod = nil;
			NSDictionary<NSString *, id> *jsonResponse = nil;
			NSError *jsonError = nil;
			OCHTTPRequestParameters requestParameters = nil;
			OCHTTPHeaderFields requestHeaderFields = nil;

			if ((error == nil) && (responseBody != nil))
			{
				id rawJSON = nil;

				if ((rawJSON = [NSJSONSerialization JSONObjectWithData:responseBody options:0 error:&jsonError]) != nil)
				{
					if ((jsonResponse = OCTypedCast(rawJSON, NSDictionary)) == nil)
					{
						error = OCErrorFromError(OCErrorResponseUnknownFormat, response.status.error);
					}
				}
			}

			if ((error == nil) && response.status.isSuccess && (jsonResponse != nil))
			{
				NSString *appURLString;
				NSString *methodString;

				if ((appURLString = OCTypedCast(jsonResponse[@"app_url"], NSString)) != nil)
				{
					appURL = [NSURL URLWithString:appURLString];
				}

				if ((methodString = OCTypedCast(jsonResponse[@"method"], NSString)) != nil)
				{
					if ([methodString isEqual:@"GET"])  { httpMethod = OCHTTPMethodGET; }
					if ([methodString isEqual:@"POST"]) { httpMethod = OCHTTPMethodPOST; }
				}

				if (staticHeaderFields.count > 0)
				{
					requestHeaderFields = [[NSMutableDictionary alloc] initWithDictionary:staticHeaderFields];
				}

				if ([httpMethod isEqual:OCHTTPMethodGET])
				{
					NSDictionary<NSString *, id> *rawHeaders;

					if ((rawHeaders = OCTypedCast(jsonResponse[@"headers"], NSDictionary)) != nil)
					{
						if (requestHeaderFields == nil) { requestHeaderFields = [NSMutableDictionary new]; }

						[rawHeaders enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
							NSString *stringKey, *stringValue;

							if (((stringKey = OCTypedCast(key, NSString)) != nil) && ((stringValue = OCTypedCast(obj, NSString)) != nil))
							{
								requestHeaderFields[stringKey] = stringValue;
							}
							else
							{
								OCLogWarning(@"App Provider Open response 'headers' contained non-string key or value: key=%@, value=%@", key, obj);
							}
						}];
					}
				}

				if ([httpMethod isEqual:OCHTTPMethodPOST])
				{
					NSDictionary<NSString *, id> *rawRequestParameters;

					if ((rawRequestParameters = OCTypedCast(jsonResponse[@"form_parameters"], NSDictionary)) != nil)
					{
						requestParameters = [NSMutableDictionary new];

						[rawRequestParameters enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
							NSString *stringKey, *stringValue;

							if (((stringKey = OCTypedCast(key, NSString)) != nil) && ((stringValue = OCTypedCast(obj, NSString)) != nil))
							{
								requestParameters[stringKey] = stringValue;
							}
							else
							{
								OCLogWarning(@"App Provider Open response 'form_parameters' contained non-string key or value: key=%@, value=%@", key, obj);
							}
						}];
					}
				}
			}
			else if (error == nil)
			{
				NSError *fallbackError = nil;

				switch (response.status.code)
				{
					case OCHTTPStatusCodeTOO_EARLY:
						error = fallbackError = OCErrorWithDescription(OCErrorItemProcessing, OCLocalized(@"This file is currently being processed and is not yet available for use. Please try again shortly."));
					break;

					default:
						fallbackError = response.status.error;
					break;
				}

				if (error == nil)
				{
					error = [NSError errorFromOCISErrorDictionary:jsonResponse underlyingError:fallbackError];
				}
			}

			if (error == nil)
			{
				if (appURL == nil)
				{
					error = OCErrorWithDescription(OCErrorResponseUnknownFormat, @"Mandatory 'app_url' information missing or invalid.");
				}
				if (httpMethod == nil)
				{
					error = OCErrorWithDescription(OCErrorResponseUnknownFormat, @"Mandatory 'method' information missing or invalid.");
				}
			}

			if (error == nil)
			{
				NSMutableURLRequest *urlRequest = nil;

				if ((appURL != nil) && (httpMethod != nil)) // error-checked above already, this condition is only here to satisfy the static analyzer
				{
					// Apply URL + HTTP method
					urlRequest = [NSMutableURLRequest requestWithURL:appURL];
					urlRequest.HTTPMethod = httpMethod;
				}

				if (requestHeaderFields != nil)
				{
					// Apply HTTP headers
					[urlRequest setAllHTTPHeaderFields:requestHeaderFields];
				}
				if (requestParameters != nil)
				{
					// Encode and apply POST parameters
					[urlRequest setHTTPBody:[requestParameters urlFormEncodedData]];
					[urlRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:OCHTTPHeaderFieldNameContentType];
				}

				completionHandler(error, appURL, httpMethod, requestHeaderFields, requestParameters, urlRequest);
			}
			else
			{
				completionHandler(error, nil, nil, nil, nil, nil);
			}
		}];
	}
	else
	{
		completionHandler(OCError(OCErrorInternal), nil, nil, nil, nil, nil);
	}

	return (progress);
}

#pragma mark - Open in Web
- (nullable NSProgress *)openInWeb:(OCItem *)item withApp:(nullable OCAppProviderApp *)app completionHandler:(void(^)(NSError * _Nullable error, NSURL * _Nullable webURL))completionHandler
{
	NSProgress *progress = nil;
	NSURL *appListURL = [self URLForEndpoint:OCConnectionEndpointIDAppProviderOpenWeb options:nil];
	OCHTTPRequest *request;

	if ((request = [OCHTTPRequest requestWithURL:appListURL]) != nil)
	{
		request.method = OCHTTPMethodPOST;
		request.requiredSignals = [NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable];
		request.parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:
			item.fileID,	@"file_id",
			app.name,	@"app_name",
		nil];

		progress = [self sendRequest:request ephermalCompletionHandler:^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
			NSData *responseBody = response.bodyData;
			NSURL *webURL = nil;
			NSDictionary<NSString *, id> *jsonResponse = nil;
			NSError *jsonError = nil;

			if ((error == nil) && (responseBody != nil))
			{
				id rawJSON = nil;

				if ((rawJSON = [NSJSONSerialization JSONObjectWithData:responseBody options:0 error:&jsonError]) != nil)
				{
					if ((jsonResponse = OCTypedCast(rawJSON, NSDictionary)) == nil)
					{
						error = OCErrorFromError(OCErrorResponseUnknownFormat, response.status.error);
					}
				}
			}

			if ((error == nil) && response.status.isSuccess && (jsonResponse != nil))
			{
				NSString *uri;

				if ((uri = OCTypedCast(jsonResponse[@"uri"], NSString)) != nil)
				{
					webURL = [NSURL URLWithString:uri];
				}
				else
				{
					error = OCErrorWithDescription(OCErrorResponseUnknownFormat, @"Mandatory 'uri' information missing from response.");
				}
			}
			else
			{
				NSError *fallbackError = nil;

				switch (response.status.code)
				{
					case OCHTTPStatusCodeTOO_EARLY:
						error = fallbackError = OCErrorWithDescription(OCErrorItemProcessing, OCLocalized(@"This file is currently being processed and is not yet available for use. Please try again shortly."));
					break;

					default:
						fallbackError = response.status.error;
					break;
				}

				if (error == nil)
				{
					error = [NSError errorFromOCISErrorDictionary:jsonResponse underlyingError:fallbackError];
				}
			}

			completionHandler(error, (error == nil) ? webURL : nil);
		}];
	}
	else
	{
		completionHandler(OCError(OCErrorInternal), nil);
	}

	return (progress);
}

@end
