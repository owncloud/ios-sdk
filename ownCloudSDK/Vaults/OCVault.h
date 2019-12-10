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
#import "OCFeatureAvailability.h"
#import "OCBookmark.h"
#import "OCKeyValueStore.h"

#if OC_FEATURE_AVAILABLE_FILEPROVIDER
#import <FileProvider/FileProvider.h>
#endif /* OC_FEATURE_AVAILABLE_FILEPROVIDER */

@class OCDatabase;
@class OCItem;

NS_ASSUME_NONNULL_BEGIN

typedef BOOL(^OCVaultCompactSelector)(OCSyncAnchor _Nullable syncAnchor, OCItem *item);

@interface OCVault : NSObject
{
	NSUUID *_uuid;

	NSURL *_rootURL;
	NSURL *_databaseURL;
	NSURL *_filesRootURL;
	NSURL *_httpPipelineRootURL;
	NSURL *_temporaryDownloadURL;

	#if OC_FEATURE_AVAILABLE_FILEPROVIDER
	NSFileProviderDomain *_fileProviderDomain;
	NSFileProviderManager *_fileProviderManager;
	NSMutableDictionary <NSFileProviderItemIdentifier, NSNumber *> *_fileProviderSignalCountByContainerItemIdentifiers;
	NSString *_fileProviderSignalCountByContainerItemIdentifiersLock;
	#endif /* OC_FEATURE_AVAILABLE_FILEPROVIDER */

	OCDatabase *_database;
}

@property(class,nonatomic,readonly) BOOL hostHasFileProvider;

@property(strong) NSUUID *uuid; //!< ID of the vault. Typically the same as the uuid of the OCBookmark it corresponds to.
@property(strong) OCBookmark *bookmark;

@property(nullable,readonly,nonatomic) OCDatabase *database; //!< The vault's database.
@property(nullable,readonly,nonatomic) OCKeyValueStore *keyValueStore; //!< Key-value store (lazily allocated), available independant of opening/closing the vault

@property(nullable,readonly,nonatomic) NSURL *rootURL; //!< The vault's root directory
@property(nullable,readonly,nonatomic) NSURL *databaseURL; //!< The vault's SQLite database location
@property(nullable,readonly,nonatomic) NSURL *keyValueStoreURL; //!< The vault's key value store location
@property(nullable,readonly,nonatomic) NSURL *filesRootURL; //!< The vault's root URL for file storage
@property(nullable,readonly,nonatomic) NSURL *httpPipelineRootURL; //!< The vault's root URL for HTTP pipeline data
@property(nullable,readonly,nonatomic) NSURL *temporaryDownloadURL; //!< The vault's root URL for temporarily downloaded files.

#if OC_FEATURE_AVAILABLE_FILEPROVIDER
@property(nullable,readonly,nonatomic) NSFileProviderDomain *fileProviderDomain; //!< File provider domain matching the bookmark's UUID
@property(nullable,readonly,nonatomic) NSFileProviderManager *fileProviderManager; //!< File provider manager for .fileProviderDomain
#endif /* OC_FEATURE_AVAILABLE_FILEPROVIDER */

+ (BOOL)vaultInitializedForBookmark:(OCBookmark *)bookmark;

#pragma mark - Init
- (instancetype)init NS_UNAVAILABLE; //!< Always returns nil. Please use the designated initializer instead.
- (instancetype)initWithBookmark:(OCBookmark *)bookmark NS_DESIGNATED_INITIALIZER;

#pragma mark - Open & Close
- (void)openWithCompletionHandler:(nullable OCCompletionHandler)completionHandler; //!< Opens the vault and its components
- (void)closeWithCompletionHandler:(nullable OCCompletionHandler)completionHandler; //!< Closes the vault and its components

#pragma mark - Offline operations
- (void)compactWithSelector:(nullable OCVaultCompactSelector)selector completionHandler:(nullable OCCompletionHandler)completionHandler; //!< Compacts the vaults contents, disposing of unneeded files. If a selector is provided, only files for which it ALSO returns YES are disposed off.
- (void)eraseWithCompletionHandler:(nullable OCCompletionHandler)completionHandler; //!< Completely erases the vaults contents.

#pragma mark - URL and path builders
- (nullable NSURL *)localURLForItem:(OCItem *)item; //!< Builds the URL to where an item should be stored. Follows <filesRootURL>/<localID>/<fileName> pattern.
- (nullable NSURL *)localFolderURLForItem:(OCItem *)item; //!< Builds the URL to where an item's folder should be stored. Follows <filesRootURL>/<localID>/ pattern.
- (nullable NSString *)relativePathForItem:(OCItem *)item;

+ (nullable NSString *)rootPathRelativeToGroupContainerForVaultUUID:(NSUUID *)uuid;

+ (nullable NSString *)databaseFilePathRelativeToRootPathForVaultUUID:(NSUUID *)uuid;

@end

extern NSString *OCVaultPathVaults;
extern NSString *OCVaultPathHTTPPipeline;

NS_ASSUME_NONNULL_END

