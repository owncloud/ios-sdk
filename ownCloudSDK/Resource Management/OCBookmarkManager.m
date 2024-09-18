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
#import "OCDataSourceArray.h"
#import "OCBookmark+DataItem.h"

@implementation OCBookmarkManager
{
	OCDataSourceArray *_bookmarksDatasource;
}

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

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleBookmarkUpdatedNotification:) name:OCBookmarkUpdatedNotification object:nil];

		[OCIPNotificationCenter.sharedNotificationCenter addObserver:self forName:OCIPCNotificationNameBookmarkManagerListChanged withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, OCBookmarkManager * _Nonnull bookmarkManager, OCIPCNotificationName  _Nonnull notificationName) {
			[bookmarkManager loadBookmarks];
			[bookmarkManager postLocalChangeNotification];
		}];
	}

	return(self);
}

- (void)dealloc
{
	[OCIPNotificationCenter.sharedNotificationCenter removeObserver:self forName:OCIPCNotificationNameBookmarkManagerListChanged];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:OCBookmarkUpdatedNotification object:nil];
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

	@autoreleasepool {
		if ((bookmarkStoreURL = self.bookmarkStoreURL) != nil)
		{
			if ((bookmarkData = [[NSData alloc] initWithContentsOfURL:bookmarkStoreURL]) != nil)
			{
				NSMutableArray<OCBookmark *> *reconstructedBookmarks = nil;

				@try
				{
					NSArray<OCBookmark *> *existingBookmarks = nil;
					NSMutableArray<OCBookmark *> *loadedBookmarks = nil;

					loadedBookmarks = [NSKeyedUnarchiver unarchiveObjectWithData:bookmarkData];

					@synchronized(self)
					{
						existingBookmarks = [_bookmarks copy];
					}

					if (existingBookmarks != nil)
					{
						// Look for changed bookmarks and update only those that don't match the existing instances
						reconstructedBookmarks = [NSMutableArray new];

						for (OCBookmark *loadedBookmark in loadedBookmarks)
						{
							OCBookmark *existingBookmark = nil;

							for (OCBookmark *bookmark in existingBookmarks)
							{
								if ([bookmark.uuid isEqual:loadedBookmark.uuid])
								{
									existingBookmark = bookmark;
									break;
								}
							}

							if (existingBookmark == nil)
							{
								// New bookmark
								[reconstructedBookmarks addObject:loadedBookmark];
							}
							else
							{
								// Existing bookmark - check for changes
								@autoreleasepool {
									NSError *error = nil;
									NSData *existingBookmarkData = nil, *loadedBookmarkData = nil;
									BOOL isIdentical = NO;

									if ((existingBookmarkData = [NSKeyedArchiver archivedDataWithRootObject:existingBookmark requiringSecureCoding:NO error:&error]) != nil)
									{
										if ((loadedBookmarkData = [NSKeyedArchiver archivedDataWithRootObject:loadedBookmark requiringSecureCoding:NO error:&error]) != nil)
										{
											if ([existingBookmarkData isEqual:loadedBookmarkData])
											{
												isIdentical = YES;
											}
										}
									}

									if (isIdentical)
									{
										// Bookmark unchanged - use existing copy
										[reconstructedBookmarks addObject:existingBookmark];
									}
									else
									{
										// Bookmark changed - use loaded copy
										[reconstructedBookmarks addObject:loadedBookmark];
									}
								}
							}
						}
					}
					else
					{
						// No bookmarks previously loaded - just use the loaded ones
						reconstructedBookmarks = loadedBookmarks;
					}
				}
				@catch(NSException *exception) {
					OCLogError(@"Error loading bookmarks: %@", OCLogPrivate(exception));
				}

				@synchronized(self)
				{
					if (reconstructedBookmarks != nil)
					{
						_bookmarks = reconstructedBookmarks;
					}
					else
					{
						[_bookmarks removeAllObjects];
					}

					[_bookmarksDatasource setVersionedItems:_bookmarks];
				}
			}
			else
			{
				@synchronized(self)
				{
					[_bookmarks removeAllObjects];
					[_bookmarksDatasource setVersionedItems:_bookmarks];
				}
			}
		}
	}
}

- (void)saveBookmarks
{
	@autoreleasepool {
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

	[self postRemoteChangeNotification];
	[self postLocalChangeNotification];
}

#pragma mark - Change notification
- (void)postLocalChangeNotification
{
	[NSNotificationCenter.defaultCenter postNotificationName:OCBookmarkManagerListChanged object:nil];
}

- (void)postRemoteChangeNotification
{
	[OCIPNotificationCenter.sharedNotificationCenter postNotificationForName:OCIPCNotificationNameBookmarkManagerListChanged ignoreSelf:YES];
}

- (void)handleBookmarkUpdatedNotification:(NSNotification *)updateNotification
{
	BOOL saveBookmarks = NO;

	if (updateNotification.object == nil) { return; }

	@synchronized(self)
	{
		if ([_bookmarks indexOfObjectIdenticalTo:updateNotification.object] != NSNotFound)
		{
			saveBookmarks = YES;
		}
	}

	if (saveBookmarks)
	{
		[self saveBookmarks];
	}
}

#pragma mark - List mutations
- (void)addBookmark:(OCBookmark *)bookmark
{
	if (bookmark==nil) { return; }

	@synchronized(self)
	{
		[_bookmarks addObject:bookmark];

		[_bookmarksDatasource setVersionedItems:_bookmarks];
	}

	[self saveBookmarks];
}

- (void)removeBookmark:(OCBookmark *)bookmark
{
	if (bookmark==nil) { return; }

	@synchronized(self)
	{
		[_bookmarks removeObject:bookmark];

		[_bookmarksDatasource setVersionedItems:_bookmarks];
	}

	[self saveBookmarks];
}

- (void)moveBookmarkFrom:(NSUInteger)fromIndex to:(NSUInteger)toIndex
{
	@synchronized(self)
	{
		OCBookmark *bookmark = [_bookmarks objectAtIndex:fromIndex];

		[_bookmarks removeObject:bookmark];
		[_bookmarks insertObject:bookmark atIndex:toIndex];

		[_bookmarksDatasource setVersionedItems:_bookmarks];
	}

	[self saveBookmarks];
}

- (BOOL)updateBookmark:(OCBookmark *)bookmark
{
	BOOL saveAndPostUpdate = NO;

	if (bookmark==nil) { return (NO); }

	@synchronized (self)
	{
		saveAndPostUpdate = ([_bookmarks indexOfObjectIdenticalTo:bookmark] != NSNotFound);
	}

	if (saveAndPostUpdate)
	{
		@synchronized (self)
		{
			// [_bookmarksDatasource setItems:_bookmarks updated:[NSSet setWithObject:bookmark]] is more accurate, but leads to unnecessary recreation and navigation issues since this forces a recreation of mapped objects in the client sidebar even if there are no relevant changes. Therefore, make sure that user-facing important changes are included in OCBookmark+DataItem versioning - and depend on its mechanisms for this data source.
			[_bookmarksDatasource setVersionedItems:_bookmarks];
		}
		[self saveBookmarks];
	}

	return (saveAndPostUpdate);
}

- (void)replaceBookmarks:(NSArray<OCBookmark *> *)bookmarks
{
	@synchronized(self)
	{
		[_bookmarks setArray:bookmarks];
		[_bookmarksDatasource setVersionedItems:_bookmarks];
	}

	[self saveBookmarks];
}

#pragma mark - Data sources
- (OCDataSource *)bookmarksDatasource
{
	@synchronized(self)
	{
		if (_bookmarksDatasource == nil)
		{
			_bookmarksDatasource = [[OCDataSourceArray alloc] initWithItems:nil];
			_bookmarksDatasource.trackItemVersions = YES;
			[_bookmarksDatasource setVersionedItems:_bookmarks];
		}
	}
	return (_bookmarksDatasource);
}

#pragma mark - Acessing bookmarks
- (OCBookmark *)bookmarkAtIndex:(NSUInteger)index
{
	@synchronized(self)
	{
		return ([_bookmarks objectAtIndex:index]);
	}
}

- (OCBookmark *)bookmarkForUUID:(OCBookmarkUUID)uuid
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

- (OCBookmark *)bookmarkForUUIDString:(OCBookmarkUUIDString)uuidString
{
	OCBookmarkUUID uuid;

	if ((uuid = [[NSUUID alloc] initWithUUIDString:uuidString]) != nil)
	{
		return ([self bookmarkForUUID:uuid]);
	}

	return (nil);
}

@end

NSNotificationName OCBookmarkManagerListChanged = @"OCBookmarkManagerListChanged";
OCIPCNotificationName OCIPCNotificationNameBookmarkManagerListChanged = @"OCBookmarkManagerListChanged";
