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
#import "OCMacros.h"
#import "OCAppProviderApp.h"

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
			NSURL *webURL;

			if ((error == nil) && response.status.isSuccess && (responseBody!=nil))
			{
				id rawJSON;

				if ((rawJSON = [NSJSONSerialization JSONObjectWithData:responseBody options:0 error:&error]) != nil)
				{
					NSDictionary<NSString *, id> *jsonResponse;
					NSString *uri;

					if (((jsonResponse = OCTypedCast(rawJSON, NSDictionary)) != nil) &&
					    ((uri = OCTypedCast(jsonResponse[@"uri"], NSString)) != nil))
					{
						webURL = [NSURL URLWithString:uri];
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
