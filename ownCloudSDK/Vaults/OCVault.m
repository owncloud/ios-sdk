//
//  OCVault.m
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

#import "OCVault.h"
#import "OCAppIdentity.h"
#import "NSError+OCError.h"
#import "OCItem.h"
#import "OCDatabase.h"
#import "OCMacros.h"
#import "OCCore+FileProvider.h"
#import "OCHTTPPipelineManager.h"
#import "OCVault+Internal.h"
#import "OCEventQueue.h"
#import "OCCoreUpdateScheduleRecord.h"
#import "OCCore+ItemList.h"
#import "OCCore+SyncEngine.h"
#import "OCFeatureAvailability.h"
#import "OCHTTPPolicyManager.h"
#import "OCBookmark+DBMigration.h"
#import "OCDatabase+Schemas.h"
#import "OCResourceManager.h"
#import "OCDatabase+ResourceStorage.h"

@implementation OCVault

@synthesize uuid = _uuid;

@synthesize rootURL = _rootURL;
@synthesize databaseURL = _databaseURL;
@synthesize keyValueStoreURL = _keyValueStoreURL;
@synthesize filesRootURL = _filesRootURL;

@synthesize database = _database;
@synthesize keyValueStore = _keyValueStore;
@synthesize resourceManager = _resourceManager;

+ (BOOL)vaultInitializedForBookmark:(OCBookmark *)bookmark
{
	NSURL *vaultRootURL = [self rootURLForUUID:bookmark.uuid];

	return ([[NSFileManager defaultManager] fileExistsAtPath:vaultRootURL.path]);
}

#pragma mark - Fileprovider capability
+ (BOOL)hostHasFileProvider
{
	static BOOL didAutoDetectFromInfoPlist = NO;
	static BOOL hostHasFileProvider = NO;

	if (!didAutoDetectFromInfoPlist && OCAppIdentity.supportsFileProvider)
	{
		NSNumber *hasFileProvider;

		if ((hasFileProvider = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"OCHasFileProvider"]) != nil)
		{
			hostHasFileProvider = [hasFileProvider boolValue];
		}

		didAutoDetectFromInfoPlist = YES;
	}

	return (hostHasFileProvider);
}


#pragma mark - Init
- (instancetype)init
{
	return (nil);
}

- (instancetype)initWithBookmark:(OCBookmark *)bookmark
{
	if ((self = [super init]) != nil)
	{
		_bookmark = bookmark;
		_uuid = bookmark.uuid;

		#if OC_FEATURE_AVAILABLE_FILEPROVIDER
		if (OCVault.hostHasFileProvider)
		{
			_fileProviderSignalCountByContainerItemIdentifiers = [NSMutableDictionary new];
			_fileProviderSignalCountByContainerItemIdentifiersLock = @"_fileProviderSignalCountByContainerItemIdentifiersLock";
		}
		#endif /* OC_FEATURE_AVAILABLE_FILEPROVIDER */
	}
	
	return (self);
}

+ (NSURL *)rootURLForUUID:(NSUUID *)uuid
{
	return [[[[OCAppIdentity sharedAppIdentity] appGroupContainerURL] URLByAppendingPathComponent:OCVaultPathVaults] URLByAppendingPathComponent:[OCVault rootPathRelativeToGroupContainerForVaultUUID:uuid]];
}

- (NSURL *)rootURL
{
	if (_rootURL == nil)
	{
		_rootURL = [[self class] rootURLForUUID:_uuid];
	}
	
	return (_rootURL);
}

- (NSURL *)databaseURL
{
	if (_databaseURL == nil)
	{
		_databaseURL = [self.rootURL URLByAppendingPathComponent:[OCVault databaseFilePathRelativeToRootPathForVaultUUID:_uuid]];
	}

	return (_databaseURL);
}

- (NSURL *)keyValueStoreURL
{
	if (_keyValueStoreURL == nil)
	{
		_keyValueStoreURL = [self.rootURL URLByAppendingPathComponent:[OCVault keyValueStoreFilePathRelativeToRootPathForVaultUUID:_uuid]];
	}

	return (_keyValueStoreURL);
}

- (NSURL *)drivesRootURL
{
	if (_drivesRootURL == nil)
	{
		_drivesRootURL = [self.filesRootURL URLByAppendingPathComponent:@"Drives" isDirectory:YES];
	}

	return (_drivesRootURL);
}

- (NSURL *)filesRootURL
{
	if (_filesRootURL == nil)
	{
		#if OC_FEATURE_AVAILABLE_FILEPROVIDER
		if (OCVault.hostHasFileProvider)
		{
			_filesRootURL = [[NSFileProviderManager defaultManager].documentStorageURL URLByAppendingPathComponent:[_uuid UUIDString]];
		}
		else
		#endif /* OC_FEATURE_AVAILABLE_FILEPROVIDER */
		{
			_filesRootURL = [self.rootURL URLByAppendingPathComponent:@"Files"];
		}
	}

	return (_filesRootURL);
}

#if OC_FEATURE_AVAILABLE_FILEPROVIDER
- (NSFileProviderDomain *)fileProviderDomain
{
	if ((_fileProviderDomain == nil) && OCVault.hostHasFileProvider)
	{
		OCSyncExec(domainRetrieval, {
			[NSFileProviderManager getDomainsWithCompletionHandler:^(NSArray<NSFileProviderDomain *> * _Nonnull domains, NSError * _Nullable error) {
				for (NSFileProviderDomain *domain in domains)
				{
					if ([domain.identifier isEqual:self.uuid.UUIDString])
					{
						self->_fileProviderDomain = domain;
					}
				}

				OCSyncExecDone(domainRetrieval);
			}];
		});
	}

	return (_fileProviderDomain);
}

- (NSFileProviderManager *)fileProviderManager
{
	if ((_fileProviderManager == nil) && OCVault.hostHasFileProvider)
	{
		@synchronized(self)
		{
			if ((_fileProviderManager == nil) && (self.fileProviderDomain != nil))
			{
				_fileProviderManager = [NSFileProviderManager managerForDomain:self.fileProviderDomain];
			}
		}
	}

	return (_fileProviderManager);
}
#endif /* OC_FEATURE_AVAILABLE_FILEPROVIDER */

- (NSURL *)httpPipelineRootURL
{
	if (_httpPipelineRootURL == nil)
	{
		_httpPipelineRootURL = [self.rootURL URLByAppendingPathComponent:OCVaultPathHTTPPipeline];
	}

	return (_httpPipelineRootURL);
}

- (NSURL *)temporaryDownloadURL
{
	if (_temporaryDownloadURL == nil)
	{
		_temporaryDownloadURL = [self.rootURL URLByAppendingPathComponent:@"TemporaryDownloads"];
	}

	return (_temporaryDownloadURL);
}

- (OCDatabase *)database
{
	if (_database == nil)
	{
		_database = [[OCDatabase alloc] initWithURL:self.databaseURL];
	}

	return (_database);
}

- (OCKeyValueStore *)keyValueStore
{
	if (_keyValueStore == nil)
	{
		_keyValueStore = [OCKeyValueStore sharedWithURL:self.keyValueStoreURL identifier:self.uuid.UUIDString owner:nil];
		[_keyValueStore registerClass:OCEventQueue.class forKey:OCKeyValueStoreKeyOCCoreSyncEventsQueue];
		[_keyValueStore registerClass:OCCoreUpdateScheduleRecord.class forKey:OCKeyValueStoreKeyCoreUpdateScheduleRecord];
	}

	return (_keyValueStore);
}

- (OCResourceManager *)resourceManager
{
	if (_resourceManager == nil)
	{
		OCDatabase *database;

		if ((database = self.database) != nil)
		{
			_resourceManager = [[OCResourceManager alloc] initWithStorage:database];
		}
	}

	return (_resourceManager);
}

#pragma mark - Operations
- (void)openWithCompletionHandler:(OCCompletionHandler)completionHandler
{
	NSError *error = nil;

	if ([[NSFileManager defaultManager] createDirectoryAtURL:self.rootURL withIntermediateDirectories:YES attributes:@{ NSFileProtectionKey : NSFileProtectionCompleteUntilFirstUserAuthentication } error:&error])
	{
		[self.database openWithCompletionHandler:^(OCDatabase *db, NSError *error) {
			if (error == nil)
			{
				if (self.bookmark.databaseVersion < OCDatabaseVersionLatest)
				{
					self.bookmark.databaseVersion = OCDatabaseVersionLatest;
					[[NSNotificationCenter defaultCenter] postNotificationName:OCBookmarkUpdatedNotification object:self.bookmark];
				}

				self->_resourceManager = [[OCResourceManager alloc] initWithStorage:db];
			}

			completionHandler(db, error);
		}];
	}
	else
	{
		if (completionHandler != nil)
		{
			completionHandler(self, error);
		}
	}
}

- (void)closeWithCompletionHandler:(OCCompletionHandler)completionHandler
{
	[self.database closeWithCompletionHandler:completionHandler];
}

- (void)compactWithSelector:(nullable OCVaultCompactSelector)selector completionHandler:(nullable OCCompletionHandler)completionHandler
{
	[self compactInContext:nil withSelector:^BOOL(OCSyncAnchor  _Nullable syncAnchor, OCItem * _Nonnull item) {
		return (item.compactingAllowed && (item.localRelativePath != nil) && ((selector != nil) ? selector(syncAnchor, item) : YES));
	} completionHandler:completionHandler];
}

- (void)eraseDrive:(OCDriveID)driveID withCompletionHandler:(nullable OCCompletionHandler)completionHandler
{
	if ((self.rootURL != nil) && (driveID != nil))
	{
		NSURL *driveRootURL = [self localDriveRootURLForDriveID:driveID];

		dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
			NSError *error = nil;

			NSFileManager *fileManager = [NSFileManager new];

			fileManager.delegate = self;

			if ([fileManager fileExistsAtPath:driveRootURL.path])
			{
				if (![fileManager removeItemAtURL:driveRootURL error:&error])
				{
					if (error == nil)
					{
						error = OCError(OCErrorInternal);
					}
				}

				OCFileOpLog(@"rm", error, @"Removing drive root for %@ at %@", driveID, driveRootURL.path);
			}

			if (completionHandler != nil)
			{
				completionHandler(self, error);
			}
		});
	}
	else
	{
		completionHandler(self, OCError(OCErrorInsufficientParameters));
	}
}

- (void)eraseWithCompletionHandler:(OCCompletionHandler)completionHandler
{
	if (self.rootURL != nil)
	{
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
			NSError *error = nil;

			NSFileManager *fileManager = [NSFileManager new];

			fileManager.delegate = self;

			if ([fileManager fileExistsAtPath:self.httpPipelineRootURL.path])
			{
				OCSyncExec(waitForPipelineDetachAndDestroy, {
					[OCHTTPPipelineManager.sharedPipelineManager detachAndDestroyPartitionInAllPipelines:self->_uuid.UUIDString completionHandler:^(id sender, NSError *error) {
						OCSyncExecDone(waitForPipelineDetachAndDestroy);
					}];
				});
			}

			if ([fileManager fileExistsAtPath:self.rootURL.path])
			{
				if (![fileManager removeItemAtURL:self.rootURL error:&error])
				{
					if (error == nil)
					{
						error = OCError(OCErrorInternal);
					}
				}

				OCFileOpLog(@"rm", error, @"Removed vault at %@", self.rootURL.path);
			}

			if ([fileManager fileExistsAtPath:self.filesRootURL.path])
			{
				if (![fileManager removeItemAtURL:self.filesRootURL error:&error])
				{
					if (error == nil)
					{
						error = OCError(OCErrorInternal);
					}
				}

				OCFileOpLog(@"rm", error, @"Removed files root at %@", self.filesRootURL.path);
			}

			if (completionHandler != nil)
			{
				completionHandler(self, error);
			}
		});
	}
	else
	{
		completionHandler(self, OCError(OCErrorInsufficientParameters));
	}
}

#pragma mark - URL and path builders
- (NSURL *)localDriveRootURLForDriveID:(nullable OCDriveID)driveID
{
	// Returns the root folder for the drive with ID driveID
	if (driveID == nil)
	{
		// oC10 items have no drive ID, so just return the filesRootURL
		return (self.filesRootURL);
	}

	// Otherwise return
	return ([self.drivesRootURL URLByAppendingPathComponent:driveID isDirectory:YES]);
}

- (NSURL *)localURLForItem:(OCItem *)item
{
	// Build the URL to where an item should be stored. Follow <filesRootURL>/<localID>/<fileName> pattern.
	return ([[self localDriveRootURLForDriveID:item.driveID] URLByAppendingPathComponent:[self relativePathForItem:item] isDirectory:NO]);
}

- (NSURL *)localFolderURLForItem:(OCItem *)item
{
	// Build the URL to where an item's folder should be stored. Follows <filesRootURL>/<localID>/ pattern.
	return ([[self localDriveRootURLForDriveID:item.driveID] URLByAppendingPathComponent:item.localID isDirectory:YES]);
}

- (NSString *)relativePathForItem:(OCItem *)item
{
	// Build the URL to where an item should be stored. Follow <filesRootURL>/<localID>/<fileName> pattern.
	return ([item.localID stringByAppendingPathComponent:item.name]);
}

+ (NSString *)rootPathRelativeToGroupContainerForVaultUUID:(NSUUID *)uuid
{
	return (uuid.UUIDString);
}

+ (NSString *)databaseFilePathRelativeToRootPathForVaultUUID:(NSUUID *)uuid
{
	return ([uuid.UUIDString stringByAppendingString:@".db"]);
}

+ (NSString *)keyValueStoreFilePathRelativeToRootPathForVaultUUID:(NSUUID *)uuid
{
	return ([uuid.UUIDString stringByAppendingString:@".ockvs"]);
}

+ (NSURL *)httpPipelineRootURL
{
	return [[[OCAppIdentity sharedAppIdentity] appGroupContainerURL] URLByAppendingPathComponent:OCVaultPathHTTPPipeline];
}

@end

NSString *OCVaultPathVaults = @"Vaults";
NSString *OCVaultPathHTTPPipeline = @"HTTPPipeline";

