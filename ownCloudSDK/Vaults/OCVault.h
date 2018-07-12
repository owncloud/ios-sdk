//
//  OCVault.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.02.18.
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

@class OCDatabase;
@class OCItem;

@interface OCVault : NSObject
{
	NSUUID *_uuid;

	NSURL *_rootURL;
	NSURL *_databaseURL;
	NSURL *_filesRootURL;
	NSURL *_connectionDataRootURL;

	OCDatabase *_database;
}

@property(strong) NSUUID *uuid; //!< ID of the vault. Typically the same as the uuid of the OCBookmark it corresponds to.

@property(readonly,nonatomic) OCDatabase *database; //!< The vault's database.

@property(readonly,nonatomic) NSURL *rootURL; //!< The vault's root directory
@property(readonly,nonatomic) NSURL *databaseURL; //!< The vault's SQLite database
@property(readonly,nonatomic) NSURL *filesRootURL; //!< The vault's root URL for file storage
@property(readonly,nonatomic) NSURL *connectionDataRootURL; //!< The vault's root URL for connection data

#pragma mark - Init
- (instancetype)init NS_UNAVAILABLE; //!< Always returns nil. Please use the designated initializer instead.
- (instancetype)initWithBookmark:(OCBookmark *)bookmark NS_DESIGNATED_INITIALIZER;

#pragma mark - Operations
- (void)openWithCompletionHandler:(OCCompletionHandler)completionHandler; //!< Opens the vault and its components
- (void)closeWithCompletionHandler:(OCCompletionHandler)completionHandler; //!< Closes the vault and its components

- (void)eraseWithCompletionHandler:(OCCompletionHandler)completionHandler; //!< Completely erases the vaults contents.

#pragma mark - URL and path builders
- (NSURL *)localURLForItem:(OCItem *)item; //!< Builds the URL to where an item should be stored. Follows <filesRootURL>/<fileID>/<fileName> pattern.

+ (NSString *)rootPathRelativeToGroupContainerForVaultUUID:(NSUUID *)uuid;

+ (NSString *)databaseFilePathRelativeToRootPathForVaultUUID:(NSUUID *)uuid;

@end

extern NSString *OCVaultPathVaults;
extern NSString *OCVaultPathConnectionData;
