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
#import <FileProvider/FileProvider.h>
#import "OCBookmark.h"

@class OCDatabase;
@class OCItem;

NS_ASSUME_NONNULL_BEGIN

@interface OCVault : NSObject
{
	NSUUID *_uuid;

	NSURL *_rootURL;
	NSURL *_databaseURL;
	NSURL *_filesRootURL;
	NSURL *_httpPipelineRootURL;
	NSURL *_temporaryDownloadURL;

	NSFileProviderDomain *_fileProviderDomain;

	OCDatabase *_database;
}

@property(strong) NSUUID *uuid; //!< ID of the vault. Typically the same as the uuid of the OCBookmark it corresponds to.

@property(nullable,readonly,nonatomic) OCDatabase *database; //!< The vault's database.

@property(nullable,readonly,nonatomic) NSURL *rootURL; //!< The vault's root directory
@property(nullable,readonly,nonatomic) NSURL *databaseURL; //!< The vault's SQLite database
@property(nullable,readonly,nonatomic) NSURL *filesRootURL; //!< The vault's root URL for file storage
@property(nullable,readonly,nonatomic) NSURL *httpPipelineRootURL; //!< The vault's root URL for HTTP pipeline data
@property(nullable,readonly,nonatomic) NSURL *temporaryDownloadURL; //1< The vault's root address for temporarily downloaded files.

@property(nullable,readonly,nonatomic) NSFileProviderDomain *fileProviderDomain; //!< File provider domain matching the bookmark's UUID

+ (BOOL)vaultInitializedForBookmark:(OCBookmark *)bookmark;

#pragma mark - Init
- (instancetype)init NS_UNAVAILABLE; //!< Always returns nil. Please use the designated initializer instead.
- (instancetype)initWithBookmark:(OCBookmark *)bookmark NS_DESIGNATED_INITIALIZER;

#pragma mark - Operations
- (void)openWithCompletionHandler:(nullable OCCompletionHandler)completionHandler; //!< Opens the vault and its components
- (void)closeWithCompletionHandler:(nullable OCCompletionHandler)completionHandler; //!< Closes the vault and its components

- (void)eraseWithCompletionHandler:(nullable OCCompletionHandler)completionHandler; //!< Completely erases the vaults contents.

#pragma mark - URL and path builders
- (nullable NSURL *)localURLForItem:(OCItem *)item; //!< Builds the URL to where an item should be stored. Follows <filesRootURL>/<fileID>/<fileName> pattern.
- (nullable NSString *)relativePathForItem:(OCItem *)item;

+ (nullable NSString *)rootPathRelativeToGroupContainerForVaultUUID:(NSUUID *)uuid;

+ (nullable NSString *)databaseFilePathRelativeToRootPathForVaultUUID:(NSUUID *)uuid;

@end

extern NSString *OCVaultPathVaults;
extern NSString *OCVaultPathHTTPPipeline;

NS_ASSUME_NONNULL_END

