//
//  OCKeyValueStore.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.07.18.
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

#import "OCKeyValueStore.h"

@implementation OCKeyValueStore

@synthesize rootURL = _rootURL;

- (instancetype)initWithRootURL:(NSURL *)rootURL
{
	if ((self = [super init]) != nil)
	{
		_rootURL = rootURL;

		if (_rootURL != nil)
		{
			[[NSFileManager defaultManager] createDirectoryAtURL:_rootURL withIntermediateDirectories:YES attributes:nil error:nil];
		}
	}

	return(self);
}

#pragma mark - Internals
- (NSURL *)_urlForKey:(NSString *)key
{
	return ([self.rootURL URLByAppendingPathComponent:key]);
}

- (NSData *)_dataForKey:(NSString *)key
{
	return ([NSData dataWithContentsOfURL:[self _urlForKey:key]]);
}

- (void)_setData:(NSData *)data forKey:(NSString *)key
{
	NSURL *url = [self _urlForKey:key];

	if (data != nil)
	{
		[data writeToURL:url atomically:YES];
	}
	else
	{
		[[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
	}
}

#pragma mark - Keyed subscripting support
- (id)objectForKeyedSubscript:(NSString *)key
{
	NSData *data;
	id retObj = nil;

	if ((data = [self _dataForKey:key]) != nil)
	{
		@try
		{
			retObj = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		}
		@catch(NSException *exception) {}
	}

	return (retObj);
}

- (void)setObject:(id)object forKeyedSubscript:(NSString *)key
{
	NSData *data = nil;

	if (object != nil)
	{
		@try
		{
			data = [NSKeyedArchiver archivedDataWithRootObject:object];
		}
		@catch(NSException *exception) {}
	}

	[self _setData:data forKey:key];
}

#pragma mark - Retrieve all keys
- (NSArray <NSString *> *)allKeys
{
	NSArray <NSURL *> *contents;
	NSMutableArray <NSString *> *allKeys = nil;

	if ((contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:self.rootURL includingPropertiesForKeys:nil options:(NSDirectoryEnumerationSkipsSubdirectoryDescendants|NSDirectoryEnumerationSkipsHiddenFiles) error:NULL]) != nil)
	{
		allKeys = [NSMutableArray new];

		for (NSURL *keyURL in contents)
		{
			[allKeys addObject:[keyURL lastPathComponent]];
		}
	}

	return (allKeys);
}

#pragma mark - Erase backing store
- (NSError *)eraseBackinngStore
{
	NSError *error = nil;

	[[NSFileManager defaultManager] removeItemAtURL:_rootURL error:&error];

	return (error);
}

@end
