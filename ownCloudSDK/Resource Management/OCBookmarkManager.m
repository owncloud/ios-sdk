//
//  OCBookmarkManager.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 08.06.18.
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

#import "OCBookmarkManager.h"
#import "OCAppIdentity.h"
#import "OCLogger.h"

@implementation OCBookmarkManager

@synthesize bookmarks = _bookmarks;

#pragma mark - Init
+ (instancetype)sharedBookmarkManager
{
	static OCBookmarkManager *sharedManager;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		sharedManager = [OCBookmarkManager new];

		[sharedManager loadBookmarks];
	});

	return (sharedManager);
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_bookmarks = [NSMutableArray new];
	}

	return(self);
}

#pragma mark - Bookmark storage
- (NSURL *)bookmarkStoreURL
{
	return ([OCAppIdentity.sharedAppIdentity.appGroupContainerURL URLByAppendingPathComponent:@"bookmarks.dat"]);
}

- (void)loadBookmarks
{
	NSData *bookmarkData;
	NSURL *bookmarkStoreURL;

	if ((bookmarkStoreURL = self.bookmarkStoreURL) != nil)
	{
		if ((bookmarkData = [[NSData alloc] initWithContentsOfURL:bookmarkStoreURL]) != nil)
		{
			NSMutableArray *loadedBookmarks = nil;

			@try
			{
				loadedBookmarks = [NSKeyedUnarchiver unarchiveObjectWithData:bookmarkData];
			}
			@catch(NSException *exception) {
				OCLogError(@"Error loading bookmarks: %@", OCLogPrivate(exception));
			}

			if (loadedBookmarks != nil)
			{
				@synchronized(self)
				{
					_bookmarks = loadedBookmarks;
				}
			}
		}
	}
}

- (void)saveBookmarks
{
	@synchronized(self)
	{
		if (_bookmarks != nil)
		{
			NSData *bookmarkData = nil;

			@try
			{
				bookmarkData = [NSKeyedArchiver archivedDataWithRootObject:_bookmarks];
			}
			@catch(NSException *exception) {
				OCLogError(@"Error archiving bookmarks: %@", OCLogPrivate(exception));
			}

			[bookmarkData writeToURL:self.bookmarkStoreURL atomically:YES];
		}
	}
}

#pragma mark - Change notification
- (void)postChangeNotification
{
	[NSNotificationCenter.defaultCenter postNotificationName:OCBookmarkManagerListChanged object:nil];
}

#pragma mark - List mutations
- (void)addBookmark:(OCBookmark *)bookmark
{
	if (bookmark==nil) { return; }

	@synchronized(self)
	{
		[_bookmarks addObject:bookmark];
	}

	[self postChangeNotification];
	[self saveBookmarks];
}

- (void)removeBookmark:(OCBookmark *)bookmark
{
	if (bookmark==nil) { return; }

	@synchronized(self)
	{
		[_bookmarks removeObject:bookmark];
	}

	[self postChangeNotification];
	[self saveBookmarks];
}

- (void)moveBookmarkFrom:(NSUInteger)fromIndex to:(NSUInteger)toIndex
{
	@synchronized(self)
	{
		OCBookmark *bookmark = [_bookmarks objectAtIndex:fromIndex];

		[_bookmarks removeObject:bookmark];
		[_bookmarks insertObject:bookmark atIndex:toIndex];
	}

	[self postChangeNotification];
	[self saveBookmarks];
}

#pragma mark - Acessing bookmarks
- (OCBookmark *)bookmarkAtIndex:(NSUInteger)index
{
	@synchronized(self)
	{
		return ([_bookmarks objectAtIndex:index]);
	}
}

- (OCBookmark *)bookmarkForUUID:(NSUUID *)uuid
{
	@synchronized(self)
	{
		for (OCBookmark *bookmark in _bookmarks)
		{
			if ([bookmark.uuid isEqual:uuid])
			{
				return (bookmark);
			}
		}
	}

	return (nil);
}

@end

NSNotificationName OCBookmarkManagerListChanged = @"OCBookmarkManagerListChanged";
