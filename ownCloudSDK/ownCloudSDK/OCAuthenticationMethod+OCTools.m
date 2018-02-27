//
//  OCAuthenticationMethod+OCTools.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 26.02.18.
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

#import "OCAuthenticationMethod+OCTools.h"

@implementation OCAuthenticationMethod (OCTools)

+ (NSString *)basicAuthorizationValueForUsername:(NSString *)username passphrase:(NSString *)passPhrase
{
	return ([NSString stringWithFormat:@"Basic %@", [[[NSString stringWithFormat:@"%@:%@", username, passPhrase] dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]]);
}

+ (NSArray <NSURL *> *)detectionURLsBasedOnWWWAuthenticateMethod:(NSString *)wwwAuthenticateMethod forConnection:(OCConnection *)connection
{
	NSURL *webDavEndpointURL;
	
	if ((webDavEndpointURL = [connection URLForEndpoint:OCConnectionEndpointIDWebDAV options:nil]) != nil)
	{
		return (@[ webDavEndpointURL ]);
	}

	return(nil);
}

+ (void)detectAuthenticationMethodSupportBasedOnWWWAuthenticateMethod:(NSString *)wwwAuthenticateMethod forConnection:(OCConnection *)connection withServerResponses:(NSDictionary<NSURL *, OCConnectionRequest *> *)serverResponses completionHandler:(void(^)(OCAuthenticationMethodIdentifier identifier, BOOL supported))completionHandler
{
	BOOL methodDetected = NO;

	if ((serverResponses != nil) && (wwwAuthenticateMethod!=nil))
	{
		wwwAuthenticateMethod = [wwwAuthenticateMethod lowercaseString];
	
		for (OCConnectionRequest *detectionRequest in serverResponses.allValues)
		{
			NSString *wwwAuthenticateHeader;
			
			// wwwAuthenticateHeader is something like 'Bearer realm="ownCloud", Basic realm="ownCloud"'
			if ((wwwAuthenticateHeader = detectionRequest.response.allHeaderFields[@"Www-Authenticate"]) != nil)
			{
				NSArray <NSString *> *components = [wwwAuthenticateHeader componentsSeparatedByString:@","];
				
				for (NSString *component in components)
				{
					if ([[[component stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString] hasPrefix:wwwAuthenticateMethod])
					{
						methodDetected = YES;
					}
				}
			}
		}
	}

	if (completionHandler!=nil)
	{
		completionHandler([self identifier], methodDetected);
	}
}


@end
