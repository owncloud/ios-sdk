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
		}
		else
		{
			endpointPath = [self classSettingForOCClassSettingsKey:endpoint];
		}

		return (endpointPath);
	}
	
	return (nil);
}

- (NSURL *)URLForEndpoint:(OCConnectionEndpointID)endpoint options:(NSDictionary <NSString *,id> *)options
{
	NSString *endpointPath;
	
	if ((endpointPath = [self pathForEndpoint:endpoint]) != nil)
	{
		return ([[_bookmark.url URLByAppendingPathComponent:endpointPath] absoluteURL]);
	}

	return (nil);
}

- (NSURL *)URLForEndpointPath:(OCPath)endpointPath
{
	if (endpointPath != nil)
	{
		return ([[NSURL URLWithString:endpointPath relativeToURL:_bookmark.url] absoluteURL]);
	}
	
	return (_bookmark.url);
}

#pragma mark - Base URL Extract
- (NSURL *)extractBaseURLFromRedirectionTargetURL:(NSURL *)inRedirectionTargetURL originalURL:(NSURL *)inOriginalURL
{
	return ([[self class] extractBaseURLFromRedirectionTargetURL:inRedirectionTargetURL originalURL:inOriginalURL originalBaseURL:[_bookmark.url absoluteURL]]);
}

+ (NSURL *)extractBaseURLFromRedirectionTargetURL:(NSURL *)inRedirectionTargetURL originalURL:(NSURL *)inOriginalURL originalBaseURL:(NSURL *)inOriginalBaseURL
{
	NSURL *originalBaseURL = [inOriginalBaseURL absoluteURL];
	NSURL *originalURL = [inOriginalURL absoluteURL];
	NSURL *redirectionTargetURL = [inRedirectionTargetURL absoluteURL];

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
						return ([NSURL URLWithString:[redirectionTargetURL.absoluteString substringToIndex:endpointPathRange.location]]);
					}
				}
			}
		}
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
