//
//  OCConnection+Tools.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 01.03.18.
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

@implementation OCConnection (Tools)

#pragma mark - Endpoints
- (NSString *)pathForEndpoint:(OCConnectionEndpointID)endpoint
{
	if (endpoint != nil)
	{
		NSString *endpointPath = nil;

		if ([endpoint isEqualToString:OCConnectionEndpointIDWebDAVRoot])
		{
			endpointPath = [self classSettingForOCClassSettingsKey:OCConnectionEndpointIDWebDAV];

			if (_loggedInUser.userName != nil)
			{
				endpointPath = [endpointPath stringByAppendingPathComponent:_loggedInUser.userName];
			}
			else
			{
				NSString *bookmarkUsername = _bookmark.userName;

				if (bookmarkUsername != nil)
				{
					endpointPath = [endpointPath stringByAppendingPathComponent:bookmarkUsername];
				}
				else
				{
					OCLogError(@"Could not generate path for endpoint %@ because the username is missing", endpoint);
					endpointPath = nil;
				}
			}
		}
		else
		{
			endpointPath = [self classSettingForOCClassSettingsKey:endpoint];
		}

		return (endpointPath);
	}
	
	return (nil);
}

- (NSURL *)URLForEndpoint:(OCConnectionEndpointID)endpoint options:(NSDictionary <OCConnectionEndpointURLOption,id> *)options
{
	NSString *endpointPath;
	
	if ((endpointPath = [self pathForEndpoint:endpoint]) != nil)
	{
		NSURL *url = [self URLForEndpointPath:endpointPath];

		if ([endpoint isEqualToString:OCConnectionEndpointIDWellKnown])
		{
			NSString *subPath;

			if ((subPath = options[OCConnectionEndpointURLOptionWellKnownSubPath]) != nil)
			{
				url = [url URLByAppendingPathComponent:subPath isDirectory:NO];
			}
		}

		if ([endpoint isEqualToString:OCConnectionEndpointIDWebDAV] && (options == nil))
		{
			// Ensure WebDAV endpoint path is slash-terminated
			if (![url.absoluteString hasSuffix:@"/"])
			{
				url = [NSURL URLWithString:[url.absoluteString stringByAppendingString:@"/"]];
			}
		}

		return (url);
	}
	else
	{
		OCLogError(@"Path for endpoint %@ with options %@ could not be generated", endpoint, options);
	}

	return (nil);
}

- (NSURL *)URLForEndpointPath:(OCPath)endpointPath
{
	if (endpointPath != nil)
	{
		NSURL *bookmarkURL = _bookmark.url;

		if ([endpointPath hasPrefix:@"/"]) // Absolute path
		{
			// Remove leading "/"
			endpointPath = [endpointPath substringFromIndex:1];

			// Strip subpaths from bookmarkURL
			while ((![[bookmarkURL path] isEqual:@"/"]) && (![[bookmarkURL path] isEqual:@""]))
			{
				bookmarkURL = [bookmarkURL URLByDeletingLastPathComponent];
			};
		}

		return ([[bookmarkURL URLByAppendingPathComponent:endpointPath] absoluteURL]);
	}
	
	return (_bookmark.url);
}

#pragma mark - Base URL Extract
- (NSURL *)extractBaseURLFromRedirectionTargetURL:(NSURL *)inRedirectionTargetURL originalURL:(NSURL *)inOriginalURL fallbackToRedirectionTargetURL:(BOOL)fallbackToRedirectionTargetURL
{
	return ([[self class] extractBaseURLFromRedirectionTargetURL:inRedirectionTargetURL originalURL:inOriginalURL originalBaseURL:[_bookmark.url absoluteURL] fallbackToRedirectionTargetURL:(BOOL)fallbackToRedirectionTargetURL]);
}

+ (NSURL *)extractBaseURLFromRedirectionTargetURL:(NSURL *)inRedirectionTargetURL originalURL:(NSURL *)inOriginalURL originalBaseURL:(NSURL *)inOriginalBaseURL fallbackToRedirectionTargetURL:(BOOL)fallbackToRedirectionTargetURL
{
	NSURL *originalBaseURL = [inOriginalBaseURL absoluteURL];
	NSURL *originalURL = [inOriginalURL absoluteURL];
	NSURL *redirectionTargetURL = [inRedirectionTargetURL absoluteURL];

	// Find root from redirects based on https://github.com/owncloud/administration/blob/master/redirectServer/Readme.md

	if ((originalBaseURL!=nil) && (originalURL!=nil))
	{
		if ((originalURL.path!=nil) && (originalBaseURL.path!=nil))
		{
			if ([originalURL.path hasPrefix:originalBaseURL.path])
			{
				NSString *endpointPath = [originalURL.path substringFromIndex:originalBaseURL.path.length];
				
				if (endpointPath.length > 1)
				{
					NSRange endpointPathRange = [redirectionTargetURL.absoluteString rangeOfString:endpointPath];
					
					if (endpointPathRange.location != NSNotFound)
					{
						// redirectURL replicates the path originally targeted URL
						return ([NSURL URLWithString:[redirectionTargetURL.absoluteString substringToIndex:endpointPathRange.location]]);
					}
				}
			}
		}
	}

	// Strip common suffixes from redirectionTargetURL
	if (fallbackToRedirectionTargetURL)
	{
		if ([redirectionTargetURL.lastPathComponent isEqual:@"status.php"])
		{
			redirectionTargetURL = redirectionTargetURL.URLByDeletingLastPathComponent;
		}

		// Fallback to redirectionTargetURL
		return (redirectionTargetURL);
	}

	return(nil);
}

#pragma mark - Safe upgrades
+ (BOOL)isAlternativeBaseURL:(NSURL *)alternativeBaseURL safeUpgradeForPreviousBaseURL:(NSURL *)baseURL
{
	if ((alternativeBaseURL!=nil) && (baseURL!=nil))
	{
		return (([alternativeBaseURL.host isEqual:baseURL.host]) &&
			([alternativeBaseURL.path isEqual:baseURL.path]) &&
			([baseURL.scheme isEqual:@"http"] && [alternativeBaseURL.scheme isEqual:@"https"]));
	}
	
	return(NO);
}

@end
