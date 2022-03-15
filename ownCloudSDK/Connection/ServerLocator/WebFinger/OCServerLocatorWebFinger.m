//
//  OCServerLocatorWebFinger.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 08.11.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCServerLocatorWebFinger.h"
#import "OCHTTPRequest.h"
#import "OCMacros.h"
#import "NSError+OCError.h"
#import "OCExtensionManager.h"
#import "OCExtension+ServerLocator.h"

NSString *OCServerLocatorWebFingerRelServerInstance = @"http://webfinger.owncloud/rel/server-instance";

@implementation OCServerLocatorWebFinger

+ (void)load
{
	[OCExtensionManager.sharedExtensionManager addExtension:[OCExtension serverLocatorExtensionWithIdentifier:OCServerLocatorIdentifierWebFinger locations:@[] metadata:@{
		OCExtensionMetadataKeyDescription : [NSString stringWithFormat:@"Locate server via Webfinger service-instance relation (%@) using the entered/provided server URL", OCServerLocatorWebFingerRelServerInstance]
	} provider:^OCServerLocator * _Nullable(OCExtension * _Nonnull extension, OCExtensionContext * _Nonnull context, NSError * _Nullable __autoreleasing * _Nullable error) {
		return ([self new]);
	}]];
}

- (NSError *)locate
{
	NSURL *webFingerURL = [self.url URLByAppendingPathComponent:@".well-known/webfinger" isDirectory:NO];
	OCHTTPRequest *webFingerRequest = [OCHTTPRequest requestWithURL:webFingerURL];

	webFingerRequest.method = OCHTTPMethodGET;
	[webFingerRequest setValue:[@"acct:" stringByAppendingString:self.userName] forParameter:@"resource"];
	[webFingerRequest setValue:OCServerLocatorWebFingerRelServerInstance forParameter:@"rel"];

	NSError *error = self.requestSender(webFingerRequest);

	if (error == nil)
	{
		NSError *jsonError = nil;
		NSDictionary *jsonResponseDict = nil;
		OCHTTPResponse *response = webFingerRequest.httpResponse;

		if ((jsonResponseDict = [response bodyConvertedDictionaryFromJSONWithError:&jsonError]) == nil)
		{
			// Return JSON parse error
			return (jsonError);
		}
		else
		{
			if (!response.status.isSuccess)
			{
				// Return HTTP status error
				if (response.status.code == OCHTTPStatusCodeNOT_FOUND)
				{
					return (OCError(OCErrorUnknownUser));
				}

				return (response.status.error);
			}
			else
			{
				// Parse WebFinger response
				NSArray<NSDictionary<NSString *, id> *> *links;

				// Look for OCServerLocatorWebFingerRelServerInstance rel and extract the href
				if ((links = OCTypedCast(jsonResponseDict[@"links"], NSArray) ) != nil)
				{
					for (NSDictionary<NSString *, id> *linkDict in links)
					{
						if ([linkDict isKindOfClass:NSDictionary.class])
						{
							if ([linkDict[@"rel"] isEqual:OCServerLocatorWebFingerRelServerInstance])
							{
								NSString *href;

								if ((href = OCTypedCast(linkDict[@"href"], NSString)) != nil)
								{
									self.url = [NSURL URLWithString:href];

									return(nil);
								}
							}
						}
					}
				}

				// No matches found
				return (OCError(OCErrorWebFingerLacksServerInstanceRelation));
			}
		}
	}

	// Return HTTP error
	return (error);
}

@end

OCServerLocatorIdentifier OCServerLocatorIdentifierWebFinger = @"web-finger";
