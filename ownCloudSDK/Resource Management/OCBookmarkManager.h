//
//  OCBookmarkManager.h
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

#import <Foundation/Foundation.h>
#import "OCBookmark.h"
#import "OCIPNotificationCenter.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCBookmarkManager : NSObject
{
	NSMutableArray<OCBookmark *> *_bookmarks;
}

@property(strong) NSArray<OCBookmark *> *bookmarks;
@property(readonly,nonatomic) NSURL *bookmarkStoreURL;

#pragma mark - Shared instance
@property(class, readonly, strong, nonatomic) OCBookmarkManager *sharedBookmarkManager;

#pragma mark - Bookmark storage
- (void)loadBookmarks;
- (void)saveBookmarks;

#pragma mark - Change notification
- (void)postLocalChangeNotification; //!< Posts a notification to observers in the current process that the bookmark list has changed. You usually don't have to call this. OCBookmarkManager will call this method when needed, so you usually shouldn't call this method.
- (void)postRemoteChangeNotification;//!< Posts a notification to observers in other processes that the bookmark list has changed. You usually don't have to call this. OCBookmarkManager will call this method when needed, so you usually shouldn't call this method.

#pragma mark - List mutations
- (void)addBookmark:(OCBookmark *)bookmark;
- (void)removeBookmark:(OCBookmark *)bookmark;

- (void)moveBookmarkFrom:(NSUInteger)fromIndex to:(NSUInteger)toIndex;

- (BOOL)updateBookmark:(OCBookmark *)bookmark; //!< Notify the manager that properties of the bookmark have been changed. Will return YES if the bookmark is managed by the manager, NO if it's not.

#pragma mark - Acessing bookmarks
- (nullable OCBookmark *)bookmarkAtIndex:(NSUInteger)index;
- (nullable OCBookmark *)bookmarkForUUID:(OCBookmarkUUID)uuid;

@end

extern NSNotificationName OCBookmarkManagerListChanged;
extern OCIPCNotificationName OCIPCNotificationNameBookmarkManagerListChanged;

NS_ASSUME_NONNULL_END
