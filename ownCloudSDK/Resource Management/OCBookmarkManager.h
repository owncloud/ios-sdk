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

@interface OCBookmarkManager : NSObject
{
	NSMutableArray<OCBookmark *> *_bookmarks;
}

@property(strong) NSMutableArray<OCBookmark *> *bookmarks;
@property(readonly,nonatomic) NSURL *bookmarkStoreURL;

#pragma mark - Shared instance
@property(class, readonly, strong, nonatomic) OCBookmarkManager *sharedBookmarkManager;

#pragma mark - Bookmark storage
- (void)loadBookmarks;
- (void)saveBookmarks;

#pragma mark - Change notification
- (void)postChangeNotification;

#pragma mark - List mutations
- (void)addBookmark:(OCBookmark *)bookmark;
- (void)removeBookmark:(OCBookmark *)bookmark;

- (void)moveBookmarkFrom:(NSUInteger)fromIndex to:(NSUInteger)toIndex;

#pragma mark - Acessing bookmarks
- (OCBookmark *)bookmarkAtIndex:(NSUInteger)index;
- (OCBookmark *)bookmarkForUUID:(NSUUID *)uuid;

@end

extern NSNotificationName OCBookmarkManagerListChanged;
