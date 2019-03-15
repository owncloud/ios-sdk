//
//  OCConnection+Compatibility.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 25.04.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2018, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCConnection.h"
#import "NSString+OCVersionCompare.h"
#import "NSError+OCError.h"
#import "OCMacros.h"

@implementation OCConnection (Compatibility)

#pragma mark - Retrieve capabilities
- (NSProgress *)retrieveCapabilitiesWithCompletionHandler:(void(^)(NSError * _Nullable error, OCCapabilities * _Nullable capabilities))completionHandler
{
	OCHTTPRequest *request;
	NSProgress *progress = nil;

	if ((request = [OCHTTPRequest requestWithURL:[self URLForEndpoint:OCConnectionEndpointIDCapabilities options:nil]]) != nil)
	{
		request.requiredSignals = [NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable];
		[request setValue:@"json" forParameter:@"format"];

		progress = [self sendRequest:request ephermalCompletionHandler:^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
			NSData *responseBody = response.bodyData;
			OCCapabilities *capabilities = nil;

			if ((error == nil) && response.status.isSuccess && (responseBody!=nil))
			{
				NSDictionary<NSString *, id> *rawJSON;

				if ((rawJSON = [NSJSONSerialization JSONObjectWithData:responseBody options:0 error:&error]) != nil)
				{
					if ((capabilities = [[OCCapabilities alloc] initWithRawJSON:rawJSON]) != nil)
					{
						self.capabilities = capabilities;
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

			completionHandler(error, capabilities);
		}];
	}

	return (progress);
}

#pragma mark - Version
- (NSString *)serverVersion
{
	return (_serverStatus[@"version"]);
}

- (NSString *)serverVersionString
{
	return (_serverStatus[@"versionstring"]);
}

- (NSString *)serverProductName
{
	return (_serverStatus[@"productname"]);
}

- (NSString *)serverEdition
{
	return (_serverStatus[@"edition"]);
}

+ (NSString *)serverLongProductVersionStringFromServerStatus:(NSDictionary<NSString *, id> *)serverStatus
{
	NSMutableArray *nameComponents = [NSMutableArray new];

	if (serverStatus[@"productname"] != nil)
	{
		[nameComponents addObject:serverStatus[@"productname"]];
	}

	if (serverStatus[@"edition"] != nil)
	{
		[nameComponents addObject:serverStatus[@"edition"]];
	}

	if (serverStatus[@"version"] != nil)
	{
		[nameComponents addObject:serverStatus[@"version"]];
	}

	if (nameComponents.count == 0)
	{
		return (@"Unknown Server");
	}

	return ([nameComponents componentsJoinedByString:@" "]);
}

- (NSString *)serverLongProductVersionString
{
	if (_serverStatus == nil) { return (nil); }
	return ([OCConnection serverLongProductVersionStringFromServerStatus:_serverStatus]);
}

#pragma mark - API Switches
- (BOOL)runsServerVersionOrHigher:(NSString *)version
{
	return ([self.serverVersion compareVersionWith:version] >= NSOrderedSame);
}

- (BOOL)supportsPreviewAPI
{
	return ([self runsServerVersionOrHigher:@"10.0.9"]);
}

#pragma mark - Checks
- (NSError *)supportsServerVersion:(NSString *)serverVersion product:(NSString *)product longVersion:(NSString *)longVersion
{
	NSString *minimumVersion;

	if ((product!=nil) && [product.lowercaseString isEqual:@"nextcloud"])
	{
		return ([NSError errorWithDomain:OCErrorDomain code:OCErrorServerVersionNotSupported userInfo:@{
			NSLocalizedDescriptionKey : [NSString stringWithFormat:OCLocalizedString(@"Server software %@ not supported.", @""), longVersion]
		}]);
	}

	if ((minimumVersion = [self classSettingForOCClassSettingsKey:OCConnectionMinimumVersionRequired]) != nil)
	{
		if ([serverVersion compareVersionWith:minimumVersion] == NSOrderedAscending)
		{
			return ([NSError errorWithDomain:OCErrorDomain code:OCErrorServerVersionNotSupported userInfo:@{
				NSLocalizedDescriptionKey : [NSString stringWithFormat:OCLocalizedString(@"This server runs an unsupported version (%@). Version %@ or later is required by this app.", @""), longVersion, minimumVersion]
			}]);
		}
	}

	return (nil);
}

@end
