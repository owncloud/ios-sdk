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
					if ((rawJSON = OCTypedCast(rawJSON, NSDictionary)) != nil)
					{
						if ([rawJSON[@"ocs"][@"meta"][@"status"] isEqual:@"failure"])
						{
							/*
								Example error:
								{
								    "ocs": {
									"meta": {
									    "status": "failure",
									    "statuscode": 997,
									    "message": "Unauthorised",
									    "totalitems": "",
									    "itemsperpage": ""
									},
									"data": []
								    }
								}
							*/
							if ([rawJSON[@"ocs"][@"meta"][@"message"] isEqual:@"Unauthorised"] ||
							    [rawJSON[@"ocs"][@"meta"][@"statuscode"] isEqual:@(997)])
							{
								error = OCError(OCErrorAuthorizationFailed);
							}
							else
							{
								error = OCErrorWithDescription(OCErrorUnknown, rawJSON[@"ocs"][@"meta"][@"message"]);
							}
						}
						else
						{
							if ((capabilities = [[OCCapabilities alloc] initWithRawJSON:rawJSON]) != nil)
							{
								self.capabilities = capabilities;
							}
						}
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

			completionHandler(error, capabilities);
		}];
	}

	return (progress);
}

#pragma mark - Version
- (NSString *)serverVersion
{
	if (self.capabilities.version != nil)
	{
		return (self.capabilities.version);
	}

	return (_serverStatus[@"version"]);
}

- (NSString *)serverVersionString
{
	if (self.capabilities.versionString != nil)
	{
		return (self.capabilities.versionString);
	}

	return (_serverStatus[@"versionstring"]);
}

- (NSString *)serverProductName
{
	if (self.capabilities.productName != nil)
	{
		return (self.capabilities.productName);
	}

	return (_serverStatus[@"productname"]);
}

- (NSString *)serverEdition
{
	if (self.capabilities.edition != nil)
	{
		return (self.capabilities.edition);
	}

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
	if (self.capabilities.longProductVersionString != nil)
	{
		return (self.capabilities.longProductVersionString);
	}

	if (_serverStatus == nil) { return (nil); }
	return ([OCConnection serverLongProductVersionStringFromServerStatus:_serverStatus]);
}

#pragma mark - API Switches
- (BOOL)runsServerVersionOrHigher:(NSString *)version
{
	return ([self.serverVersion compareVersionWith:version] >= NSOrderedSame);
}

- (BOOL)useDriveAPI
{
	return (self.capabilities.spacesEnabled.boolValue || [self.bookmark hasCapability:OCBookmarkCapabilityDrives]);
}

#pragma mark - Checks
- (NSError *)supportsServerVersion:(NSString *)serverVersion product:(NSString *)product longVersion:(NSString *)longVersion allowHiddenVersion:(BOOL)allowHiddenVersion
{
	NSString *minimumVersion;

	if ((product!=nil) && [product.lowercaseString isEqual:@"nextcloud"])
	{
		return ([NSError errorWithDomain:OCErrorDomain code:OCErrorServerVersionNotSupported userInfo:@{
			NSLocalizedDescriptionKey : [NSString stringWithFormat:OCLocalizedString(@"Server software %@ not supported.", @""), longVersion]
		}]);
	}

	if ((([serverVersion isEqual:@""]) || (serverVersion == nil)) && allowHiddenVersion)
	{
		// Server may be using "version.hidden" option
		return (nil);
	}

	if ((minimumVersion = [self classSettingForOCClassSettingsKey:OCConnectionMinimumVersionRequired]) != nil)
	{
		if ([serverVersion compareVersionWith:minimumVersion] == NSOrderedAscending)
		{
			// ocis public beta special handling

			// NSArray<NSString *> *versionSegments = [serverVersion componentsSeparatedByString:@"."];
			// ocis returns four digit version numbers, with 2 being the major version
			// if ((versionSegments.count == 4) && [versionSegments.firstObject isEqual:@"2"])

			if ([serverVersion isEqual:@"0.0.0.0"] || [serverVersion isEqual:@"2.0.0.0"])
			{
				// ocis public beta exception
				return (nil);
			}

			return ([NSError errorWithDomain:OCErrorDomain code:OCErrorServerVersionNotSupported userInfo:@{
				NSLocalizedDescriptionKey : [NSString stringWithFormat:OCLocalizedString(@"This server runs an unsupported version (%@). Version %@ or later is required by this app.", @""), longVersion, minimumVersion]
			}]);
		}
	}

	return (nil);
}

@end
