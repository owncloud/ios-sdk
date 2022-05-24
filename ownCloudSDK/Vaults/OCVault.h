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
#import "OCLocation.h"
#import "OCVaultLocation.h"
#import "OCDrive.h"
#import "OCVFSCore.h"

#if OC_FEATURE_AVAILABLE_FILEPROVIDER
#import <FileProvider/FileProvider.h>
#endif /* OC_FEATURE_AVAILABLE_FILEPROVIDER */

@class OCDatabase;
@class OCItem;
@class OCResourceManager;

/*
	# Filesystem layout						# API

	[App Group Container]/						- OCAppIdentity.appGroupContainerURL
		"Vaults"/ 						- OCVaultPathVaults
			[Bookmark UUID]/ 				- OCVault.rootURL
				[Bookmark UUID].db			- OCVault.databaseURL
				[Bookmark UUID].tdb			  + (thumbnail part of .database)

				[Bookmark UUID].ockvs			- OCVault.keyValueStoreURL

		"HTTPPipeline"/						- OCVault.httpPipelineRootURL
			backend.sqlite					- OCHTTPPipelineManager.backendRootURL
			tmp/						- OCHTTPPipelineBackend.backendTemporaryFilesRootURL

		"TemporaryDownloads"/					- OCVault.temporaryDownloadURL
			[Random UUID] (temporary files for downloads)

		"messageQueue.dat"					- OCMessageQueue.globalQueue KVS


	[NSFileProviderManager documentStorageURL]/
		"VFS"/							- OCVault.vfsStorageRootURLForBookmarkUUID:nil
			[VFS Node ID]
			…

		[Bookmark UUID]/					- OCVault.filesRootURL
			"org.owncloud.fp-services:[Bookmark UUID]" 	- OCVault.fpServicesURL (file)

			"VFS"/						- OCVault.vfsStorageRootURLForBookmarkUUID:bookmarkUUID
				[VFS Node ID]
				…

			*OC10/without drives*
			[Local ID]/					- OCVault.localFolderURLForItem
				[filename.xyz]				- OCVault.localURLForItem


			*Drive-based*
			"Drives"/					- OCVault.drivesRootURL
				[Drive ID]/				- OCVault.localDriveRootURLForDriveID --> !! Virtual !!
					[Local ID]/			- OCVault.localFolderURLForItem
						[filename.xyz]		- OCVault.localURLForItem

 */

NS_ASSUME_NONNULL_BEGIN

typedef BOOL(^OCVaultCompactSelector)(OCSyncAnchor _Nullable syncAnchor, OCItem *item);

@interface OCVault : NSObject
{
	NSUUID *_uuid;

	NSURL *_rootURL;
	NSURL *_databaseURL;
	NSURL *_drivesRootURL;
	NSURL *_filesRootURL;
	NSURL *_httpPipelineRootURL;
	NSURL *_temporaryDownloadURL;

	#if OC_FEATURE_AVAILABLE_FILEPROVIDER
	NSFileProviderDomain *_fileProviderDomain;
	NSFileProviderManager *_fileProviderManager;
	NSMutableDictionary <OCVFSItemID, NSNumber *> *_fileProviderSignalCountByContainerItemIdentifiers;
	NSString *_fileProviderSignalCountByContainerItemIdentifiersLock;
	#endif /* OC_FEATURE_AVAILABLE_FILEPROVIDER */

	NSArray<OCDrive *> *_activeDrives;
	NSArray<OCDrive *> *_subscribedDrives;
	NSArray<OCDrive *> *_detachedDrives;
	NSDictionary<OCDriveID, OCDrive *> *_activeDrivesByID;
	NSDictionary<OCDriveID, OCDrive *> *_detachedDrivesByID;
	BOOL _observingDrivesUpdates;

	OCVFSCore *_vfsCore;

	OCDatabase *_database;
}

@property(class,nonatomic,readonly) BOOL hostHasFileProvider;

@property(strong) NSUUID *uuid; //!< ID of the vault. Typically the same as the uuid of the OCBookmark it corresponds to.
@property(strong) OCBookmark *bookmark;

@property(nullable,readonly,nonatomic) OCDatabase *database; //!< The vault's database.
@property(nullable,readonly,nonatomic) OCResourceManager *resourceManager; //!< The vault's resource manager.
@property(nullable,readonly,nonatomic) OCKeyValueStore *keyValueStore; //!< Key-value store (lazily allocated), available independant of opening/closing the vault

@property(nullable,readonly,nonatomic) NSURL *rootURL; //!< The vault's root directory
@property(nullable,readonly,nonatomic) NSURL *databaseURL; //!< The vault's SQLite database location
@property(nullable,readonly,nonatomic) NSURL *keyValueStoreURL; //!< The vault's key value store location
@property(nullable,readonly,nonatomic) NSURL *filesRootURL; //!< The vault's root URL for file storage
@property(nullable,readonly,nonatomic) NSURL *drivesRootURL; //!< The vault's root URL for drive folders
@property(nullable,readonly,nonatomic) NSURL *httpPipelineRootURL; //!< The vault's root URL for HTTP pipeline data
@property(nullable,readonly,nonatomic) NSURL *temporaryDownloadURL; //!< The vault's root URL for temporarily downloaded files.

@property(nullable,readonly,class,nonatomic) NSURL *storageRootURL; //!< The root URL for file storage for file providers

+ (NSURL *)storageRootURLForBookmarkUUID:(nullable OCBookmarkUUID)bookmarkUUID; //!< The root URL for file storage: globally for bookmarkUUID==nil, per-account if a bookmarkUUID is passed
+ (NSURL *)vfsStorageRootURLForBookmarkUUID:(nullable OCBookmarkUUID)bookmarkUUID; //!< The root URL for VFS virtual node storage: globally for bookmarkUUID==nil, per-account if a bookmarkUUID is passed

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
- (void)eraseDrive:(OCDriveID)driveID withCompletionHandler:(nullable OCCompletionHandler)completionHandler; //!< Completely erases the contents of a drive
- (void)eraseWithCompletionHandler:(nullable OCCompletionHandler)completionHandler; //!< Completely erases the vaults contents.

#pragma mark - Drives
@property(strong,readonly,nonatomic) NSArray<OCDrive *> *activeDrives; //!< All drives returned by the server
@property(strong,readonly,nonatomic) NSArray<OCDrive *> *subscribedDrives; //!< All drives the user is subscribed to
@property(strong,readonly,nonatomic) NSArray<OCDrive *> *detachedDrives; //!< Drives that no longer exist on the server but (may) have unsynced user data in them. Check OCDrive.detachedState.

- (void)updateWithRemoteDrives:(NSArray<OCDrive *> *)newDrives; //!< Uses newDrives as new list of drives available on the server to update .activeDrives, .subscribedDrives and .detachedDrives.

- (void)subscribeToDrives:(NSArray<OCDrive *> *)drives; //!< Adds the drives to the list of subscribed drives
- (void)unsubscribeFromDrives:(NSArray<OCDrive *> *)drives; //!< Removes the drives from the list of subscribed drives

- (void)changeDetachedState:(OCDriveDetachedState)detachedState forDriveID:(OCDriveID)detachedDriveID; //!< Changes the detached state for an already detached drive.
- (nullable OCDrive *)driveWithIdentifier:(OCDriveID)driveID;

- (void)startDriveUpdates; //!< Initializes the drive properties and starts observing for changes. This is usually called by -openWithCompletionHandler:. Calling this without opening a vault allows getting access to the drives list and be notified of changes. Useful mostly for VFS implementations.
- (void)stopDriveUpdates; //!< Stops observing for changes. This is usually called by -closeWithCompletionHandler:.

#pragma mark - URL and path builders
- (nullable NSURL *)localDriveRootURLForDriveID:(nullable OCDriveID)driveID; //!< Returns the root folder for the drive with ID driveID
- (nullable NSURL *)localURLForItem:(OCItem *)item; //!< Builds the URL to where an item should be stored. Follows <filesRootURL>/<localID>/<fileName> pattern.
- (nullable NSURL *)localFolderURLForItem:(OCItem *)item; //!< Builds the URL to where an item's folder should be stored. Follows <filesRootURL>/<localID>/ pattern.
- (nullable NSString *)relativePathForItem:(OCItem *)item;

+ (nullable NSString *)rootPathRelativeToGroupContainerForVaultUUID:(NSUUID *)uuid;

+ (nullable NSString *)databaseFilePathRelativeToRootPathForVaultUUID:(NSUUID *)uuid;

@property(nullable,readonly,nonatomic,class) NSURL *httpPipelineRootURL;

#pragma mark - URL/path parser
+ (nullable OCVaultLocation *)locationForURL:(NSURL *)url;
+ (nullable NSURL *)urlForLocation:(OCVaultLocation *)location;

@end

#pragma mark - VFS
@interface OCVault (VFSExtras)

@property(strong,nullable,readonly,nonatomic) OCVFSCore *vfs; //!< Returns the VFS for the vault, if any. Requires implementation of the OCVaultVFSProvider protocol in an OCVault category.
- (nullable NSArray<OCLocalID> *)translatedParentIDsForItem:(OCItem *)item suggestedRootFolderID:(nullable OCLocalID)suggestedRootFolderID;

@end

@class OCVFSCore;

@protocol OCVaultVFSTranslation
- (nullable NSSet<OCVFSItemID> *)vfsRefreshIDsForDriveChangesWithAdditions:(nullable NSArray <OCDrive *> *)addedDrives updates:(nullable NSArray<OCDrive *> *)updatedDrives removals:(nullable NSArray<OCDrive *> *)removedDrives;
- (nullable NSArray<OCVFSItemID> *)vfsRefreshParentIDsForItem:(OCItem *)item;
@end

@protocol OCVaultVFSProvider
- (nullable OCVFSCore *)provideVFS;
@end

extern NSString *OCVaultPathVaults;
extern NSString *OCVaultPathHTTPPipeline;
extern NSString *OCVaultPathDrives;
extern NSString *OCVaultPathVFS;

extern OCKeyValueStoreKey OCKeyValueStoreKeyVaultDriveList;

extern NSNotificationName OCVaultDriveListChanged; //!< Notification sent when an OCVault's drive list has changed. The object is the OCVault.

NS_ASSUME_NONNULL_END

