//
//  OCHTTPCookieStorage.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 14.08.19.
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

#import "OCHTTPCookieStorage.h"

typedef NSString* OCHTTPCookieName;

@interface OCHTTPCookieStorage ()
{
	NSMutableArray<NSHTTPCookie *> *_cookies;
//	NSMutableArray<NSDictionary<NSHTTPCookiePropertyKey, id> *> *_cookiesInProperties;
	NSMutableDictionary<OCHTTPCookieName, NSHTTPCookie *> *_cookiesByName;
}
@end


@implementation OCHTTPCookieStorage

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_cookies = [NSMutableArray new];
//		_cookiesInProperties = [NSMutableArray new];
		_cookiesByName = [NSMutableDictionary new];
	}

	return (self);
}

//- (instancetype)initWithKeyValueStore:(nullable OCKeyValueStore *)keyValueStore key:(nullable OCKeyValueStoreKey)storageKey
//{
//	if ((self = [self init]) != nil)
//	{
//		if ((_keyValueStore != nil) && (_storageKey != nil))
//		{
//			_keyValueStore = keyValueStore;
//			_storageKey = storageKey;
//
//			[_keyValueStore addObserver:^(OCKeyValueStore * _Nonnull store, id  _Nullable owner, OCKeyValueStoreKey  _Nonnull key, id  _Nullable newValue) {
//
//			} forKey:storageKey withOwner:self initial:YES];
//		}
//	}
//
//	return (self);
//}

#pragma mark - HTTP
- (void)addCookiesForPipeline:(OCHTTPPipeline *)pipeline partitionID:(OCHTTPPipelinePartitionID)partitionID toRequest:(OCHTTPRequest *)request
{
	NSArray<NSHTTPCookie *> *cookies;

	if ((cookies = [self retrieveCookiesForPipeline:pipeline partitionID:partitionID url:request.url]) != nil)
	{
		NSDictionary<NSString *, NSString *> *cookieHeaders;

		if ((cookieHeaders = [NSHTTPCookie requestHeaderFieldsWithCookies:cookies]) != nil)
		{
			[request addHeaderFields:cookieHeaders];
		}
	}
}

- (void)extractCookiesForPipeline:(nullable OCHTTPPipeline *)pipeline partitionID:(nullable OCHTTPPipelinePartitionID)partitionID fromResponse:(OCHTTPResponse *)response
{
	if ((response.headerFields != nil) && (response.httpURLResponse.URL != nil))
	{
		NSArray<NSHTTPCookie *> *cookies;

		if (((cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:response.headerFields forURL:response.httpURLResponse.URL]) != nil) && (cookies.count > 0))
		{
			if ((_cookieFilter != nil) && (cookies.count > 0))
			{
				NSMutableArray<NSHTTPCookie *> *filteredCookies = [[NSMutableArray alloc] initWithCapacity:cookies.count];

				for (NSHTTPCookie *cookie in cookies)
				{
					if (_cookieFilter(cookie))
					{
						[filteredCookies addObject:cookie];
					}
				}

				cookies = filteredCookies;
			}

			[self storeCookies:cookies forPipeline:pipeline partitionID:partitionID];
		}
	}
}


#pragma mark - Storage
//- (void)storeCookies:(NSArray<NSHTTPCookie *> *)cookies forPipeline:(nullable OCHTTPPipeline *)pipeline partitionID:(nullable OCHTTPPipelinePartitionID)partitionID
//{
//	if (cookies.count == 0) { return; }
//
//	BOOL (^StoreCookies)(void) = ^{
//		BOOL changesFound = NO;
//
//		for (NSHTTPCookie *cookie in cookies)
//		{
//			NSString *cookieName = nil;
//			NSDate *expiresDate = nil;
//			NSDictionary<NSHTTPCookiePropertyKey, id> *cookieProperties = nil;
//			BOOL expired = NO, unchangedCookie = NO;
//
//			// Check that cookie isn't expired already (=> used by servers to remove cookies from the client)
//			if ((expiresDate = cookie.expiresDate) != nil) // Not a session cookie
//			{
//				if ([expiresDate timeIntervalSinceNow] <= 0)
//				{
//					expired = YES;
//				}
//			}
//
//			// Remove existing cookie by the same name
//			if ((cookieName = cookie.name) != nil)
//			{
//				NSHTTPCookie *existingCookie;
//
//				if ((existingCookie = self->_cookiesByName[cookieName]) != nil)
//				{
//					NSUInteger existingCookieIndex;
//
//					if ((existingCookieIndex = [self->_cookies indexOfObjectIdenticalTo:existingCookie]) != NSNotFound)
//					{
//						cookieProperties = cookie.properties;
//
//						if (!expired && // Remove expired cookies
//						    [[self->_cookiesInProperties objectAtIndex:existingCookieIndex] isEqual:cookieProperties]) // Keep unchanged cookies
//						{
//							unchangedCookie = YES;
//						}
//						else
//						{
//							self->_cookiesByName[cookieName] = nil;
//							[self->_cookies removeObjectAtIndex:existingCookieIndex];
//							[self->_cookiesInProperties removeObjectAtIndex:existingCookieIndex];
//
//							changesFound = YES;
//						}
//					}
//				}
//			}
//
//			// Add cookie
//			if (!expired && // Don't store expired cookies
//			    !unchangedCookie && // Don't waste time with unchanged cookies
//			    (cookieName != nil))
//			{
//				self->_cookiesByName[cookieName] = cookie;
//				[self->_cookies addObject:cookie];
//				[self->_cookiesInProperties addObject:cookie.properties];
//
//				changesFound = YES;
//			}
//		}
//
//		return (changesFound);
//	};
//
//	@synchronized(self)
//	{
//		StoreCookies();
//	}
//}

- (void)storeCookies:(NSArray<NSHTTPCookie *> *)cookies forPipeline:(nullable OCHTTPPipeline *)pipeline partitionID:(nullable OCHTTPPipelinePartitionID)partitionID
{
	if (cookies.count == 0) { return; }

	OCTLogDebug(@[@"Store"], @"Store cookies: %@", cookies);

	@synchronized(self)
	{
		for (NSHTTPCookie *cookie in cookies)
		{
			NSString *cookieName = nil;
			NSDate *expiresDate = nil;
			BOOL expired = NO;

			// Remove existing cookie by the same name
			if ((cookieName = cookie.name) != nil)
			{
				NSHTTPCookie *existingCookie;

				if ((existingCookie = _cookiesByName[cookieName]) != nil)
				{
					[_cookies removeObjectIdenticalTo:existingCookie];
				}
			}

			// Check that cookie isn't expired already (=> used by servers to remove cookies from the client)
			if ((expiresDate = cookie.expiresDate) != nil) // Not a session cookie
			{
				if ([expiresDate timeIntervalSinceNow] <= 0)
				{
					expired = YES;
				}
			}

			// Add cookie
			if (!expired && (cookieName != nil))
			{
				_cookiesByName[cookieName] = cookie;
				[_cookies addObject:cookie];
			}
		}
	}
}

- (NSArray<NSHTTPCookie *> *)retrieveCookiesForPipeline:(OCHTTPPipeline *)pipeline partitionID:(OCHTTPPipelinePartitionID)partitionID url:(NSURL *)url
{
	NSMutableArray<NSHTTPCookie *> *matchingCookies = nil;

	@synchronized(self)
	{
		NSMutableIndexSet *removeIndexes = nil;
		NSUInteger index = 0;

		for (NSHTTPCookie *cookie in _cookies)
		{
			BOOL expired = NO;

			if ([cookie shouldApplyForURL:url expired:&expired])
			{
				// Add to matchingCookies
				if (matchingCookies == nil) { matchingCookies = [NSMutableArray new]; }
				[matchingCookies addObject:cookie];
			}
			else if (expired)
			{
				// Outdated => remove cookie
				if (removeIndexes == nil) { removeIndexes = [NSMutableIndexSet new]; }
				[removeIndexes addIndex:index];
				_cookiesByName[cookie.name] = nil;
			}

			index++;
		}

		// Remove expired cookies
		if (removeIndexes != nil)
		{
			[_cookies removeObjectsAtIndexes:removeIndexes];
		}
	}

	OCTLogDebug(@[@"Retrieve"], @"Retrieved cookies for URL %@: %@", url, matchingCookies);

	return (matchingCookies);
}

#pragma mark - Log tagging
+ (NSArray<OCLogTagName> *)logTags
{
	return (@[@"Cookies"]);
}

- (NSArray<OCLogTagName> *)logTags
{
	return (@[@"Cookies"]);
}

@end
