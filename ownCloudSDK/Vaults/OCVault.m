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
#import "NSString+OCPath.h"
#import "OCVaultDriveList.h"
#import "NSArray+OCMapping.h"
#import "NSArray+OCFiltering.h"
#import "GADrive.h"
#import "GADriveItem.h"

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
		_drivesRootURL = [self.filesRootURL URLByAppendingPathComponent:OCVaultPathDrives isDirectory:YES];
	}

	return (_drivesRootURL);
}

+ (NSURL *)storageRootURL
{
	#if OC_FEATURE_AVAILABLE_FILEPROVIDER
	static dispatch_once_t onceToken;
	static NSURL *storageRootURL;

	if (OCVault.hostHasFileProvider)
	{
		dispatch_once(&onceToken, ^{
			storageRootURL = NSFileProviderManager.defaultManager.documentStorageURL;
		});

		return (storageRootURL);
	}
	#endif /* OC_FEATURE_AVAILABLE_FILEPROVIDER */

	return (nil);
}

+ (NSURL *)storageRootURLForBookmarkUUID:(OCBookmarkUUID)bookmarkUUID
{
	if (bookmarkUUID == nil)
	{
		return ([self storageRootURL]);
	}

	return ([[self storageRootURL] URLByAppendingPathComponent:bookmarkUUID.UUIDString isDirectory:YES]);
}

+ (NSURL *)vfsStorageRootURLForBookmarkUUID:(OCBookmarkUUID)bookmarkUUID
{
	static dispatch_once_t onceToken;
	static NSURL *vsfStorageRootURL;

	dispatch_once(&onceToken, ^{
		vsfStorageRootURL = [[self storageRootURL] URLByAppendingPathComponent:@"VFS" isDirectory:YES];
	});

	if (bookmarkUUID == nil)
	{
		return (vsfStorageRootURL);
	}

	return ([[self storageRootURL] URLByAppendingPathComponent:[bookmarkUUID.UUIDString stringByAppendingPathComponent:@"VFS"] isDirectory:YES]);
}

- (NSURL *)filesRootURL
{
	if (_filesRootURL == nil)
	{
		#if OC_FEATURE_AVAILABLE_FILEPROVIDER
		if (OCVault.hostHasFileProvider)
		{
			_filesRootURL = [OCVault.storageRootURL URLByAppendingPathComponent:_uuid.UUIDString isDirectory:YES];
		}
		else
		#endif /* OC_FEATURE_AVAILABLE_FILEPROVIDER */
		{
			_filesRootURL = [self.rootURL URLByAppendingPathComponent:@"Files" isDirectory:YES];
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
		[_keyValueStore registerClass:OCVaultDriveList.class forKey:OCKeyValueStoreKeyVaultDriveList];
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

#pragma mark - VFS
- (OCVFSCore *)vfs
{
	if (_vfsCore == nil)
	{
		if ([self conformsToProtocol:@protocol(OCVaultVFSProvider)])
		{
			_vfsCore = [(id<OCVaultVFSProvider>)self provideVFS];
		}
	}

	return (_vfsCore);
}

#pragma mark - Drives
- (NSArray<OCDrive *> *)activeDrives
{
	@synchronized(self)
	{
		return (_activeDrives);
	}
}

- (void)updateWithRemoteDrives:(NSArray<OCDrive *> *)newRemoteDrives
{
	// Sort _drives by type and name
	newRemoteDrives = [newRemoteDrives sortedArrayUsingComparator:^NSComparisonResult(OCDrive *drive1, OCDrive *drive2) {
		NSComparisonResult result;

		if ((result = [drive1.type localizedCompare:drive2.type]) != NSOrderedSame)
		{
			return (result);
		}

		return ([drive1.name localizedCompare:drive2.name]);
	}];

	NSMutableSet<OCDriveID> *newDrivesIDs = [newRemoteDrives setUsingMapper:^OCDriveID(OCDrive *drive) {
		return (drive.identifier);
	}];

	__block NSMutableArray<OCDrive *> *remotelyAddedDrives = [NSMutableArray new];
	__block NSMutableArray<OCDrive *> *remotelyRemovedDrives = [NSMutableArray new];
	__block NSMutableArray<OCDrive *> *remotelyUpdatedDrives = [NSMutableArray new];

	[self _modifyDriveListWith:^OCVaultDriveList *(OCVaultDriveList *driveList, BOOL *outDidModify) {
		BOOL detachedDrivesChanged = NO;

		NSMutableSet<OCDriveID> *existingDrivesIDs = [driveList.drives setUsingMapper:^OCDriveID(OCDrive *drive) {
			return (drive.identifier);
		}];

		// Find no longer detached drives
		NSMutableArray<OCDrive *> *detachedDrives = [driveList.detachedDrives mutableCopy];

		for (OCDrive *detachedDrive in driveList.detachedDrives)
		{
			if ([newDrivesIDs containsObject:detachedDrive.identifier])
			{
				OCTLogDebug(@[@"Drives"], @"Re-attached detached drive: %@", detachedDrive);

				[detachedDrives removeObject:detachedDrive];
				detachedDrivesChanged = YES;
			}
		}

		// Find new detached drives
		for (OCDrive *drive in driveList.drives)
		{
			if (![newDrivesIDs containsObject:drive.identifier])
			{
				OCTLogDebug(@[@"Drives"], @"Newly detached drive: %@", drive);

				drive.detachedState = OCDriveDetachedStateNew;
				drive.detachedSinceDate = [NSDate new];

				[detachedDrives addObject:drive];
				[remotelyRemovedDrives addObject:drive];

				detachedDrivesChanged = YES;
			}
		}

		// Find added drives
		for (OCDrive *newRemoteDrive in newRemoteDrives)
		{
			if (![existingDrivesIDs containsObject:newRemoteDrive.identifier])
			{
				[remotelyAddedDrives addObject:newRemoteDrive];
			}
		}

		// Find updated drives
		NSMutableDictionary<OCDriveID, OCDrive *> *existingDrivesByDriveID = [driveList.drives dictionaryUsingMapper:^OCDriveID(OCDrive *drive) {
			return (drive.identifier);
		}];

		for (OCDrive *newRemoteDrive in newRemoteDrives)
		{
			if (newRemoteDrive.identifier != nil)
			{
				OCDrive *existingDrive;

				if ((existingDrive = existingDrivesByDriveID[newRemoteDrive.identifier]) != nil)
				{
					if ([newRemoteDrive isSubstantiallyDifferentFrom:existingDrive])
					{
						OCLogDebug(@"1: %d", OCNANotEqual(newRemoteDrive.identifier, existingDrive.identifier));
						OCLogDebug(@"2: %d", OCNANotEqual(newRemoteDrive.type, existingDrive.type));
						OCLogDebug(@"3: %d", OCNANotEqual(newRemoteDrive.name, existingDrive.name));
						OCLogDebug(@"4: %d", OCNANotEqual(newRemoteDrive.desc, existingDrive.desc));
						OCLogDebug(@"5: %d", OCNANotEqual(newRemoteDrive.davRootURL, existingDrive.davRootURL));
						OCLogDebug(@"6: %d", OCNANotEqual([newRemoteDrive.gaDrive specialDriveItemFor:GASpecialFolderNameImage].eTag, [existingDrive.gaDrive specialDriveItemFor:GASpecialFolderNameImage].eTag));
						OCLogDebug(@"7: %d", OCNANotEqual([newRemoteDrive.gaDrive specialDriveItemFor:GASpecialFolderNameReadme].eTag, [existingDrive.gaDrive specialDriveItemFor:GASpecialFolderNameReadme].eTag));
						OCLogDebug(@"8: %d", OCNANotEqual(newRemoteDrive.detachedSinceDate, existingDrive.detachedSinceDate));
						OCLogDebug(@"9: %d", (newRemoteDrive.detachedState != existingDrive.detachedState));
						OCLogDebug(@"10: %d", OCNANotEqual(newRemoteDrive.rootETag, existingDrive.rootETag));

						[remotelyUpdatedDrives addObject:newRemoteDrive];
					}
				}
			}
		}

		// Update drives with new remote drives
		if ((remotelyAddedDrives.count > 0) || (remotelyUpdatedDrives.count > 0) || (remotelyRemovedDrives.count > 0))
		{
			if (remotelyAddedDrives.count > 0)
			{
				OCTLogDebug(@[@"Drives"], @"Remotely added drives: %@", remotelyAddedDrives);
			}

			if (remotelyUpdatedDrives.count > 0)
			{
				OCTLogDebug(@[@"Drives"], @"Remotely updated drives: %@", remotelyUpdatedDrives);
			}

			if (remotelyRemovedDrives.count > 0)
			{
				OCTLogDebug(@[@"Drives"], @"Remotely removed drives: %@", remotelyRemovedDrives);
			}

			for (OCDrive *addedDrive in remotelyAddedDrives)
			{
				// Subscribe to new drives by default
				// (when implementing a policy here in the future, consider always subscribing to the personal space regardless of policy)
				// (also handle the return of detached drives and don't automatically re-add them as subscribed drives if they weren't before)
				[driveList.subscribedDriveIDs addObject:addedDrive.identifier];
			}

			driveList.drives = newRemoteDrives;
			*outDidModify = YES;
		}

		// Update detached drives
		if (detachedDrivesChanged)
		{
			driveList.detachedDrives = detachedDrives;
			*outDidModify = YES;
		}

		return (driveList);
	}];

	// Signal drive changes to File Provider
	if ((remotelyAddedDrives.count > 0) || (remotelyUpdatedDrives.count > 0) || (remotelyRemovedDrives.count > 0))
	{
		[self signalDriveChangesWithAdditions:remotelyAddedDrives updates:remotelyUpdatedDrives removals:remotelyRemovedDrives];
	}
}

- (NSArray<OCDrive *> *)subscribedDrives
{
	@synchronized(self)
	{
		return (_subscribedDrives);
	}
}

- (NSArray<OCDrive *> *)detachedDrives
{
	@synchronized(self)
	{
		return (_detachedDrives);
	}
}

- (void)subscribeToDrives:(NSArray<OCDrive *> *)drives
{
	[self _modifyDriveListWith:^OCVaultDriveList *(OCVaultDriveList *driveList, BOOL *outDidModify) {
		NSUInteger count = driveList.subscribedDriveIDs.count;

		for (OCDrive *drive in drives)
		{
			[driveList.subscribedDriveIDs addObject:drive.identifier];
		}

		if (count != driveList.subscribedDriveIDs.count)
		{
			OCTLogDebug(@[@"Drives"], @"Subscribed to drives: %@", drives);
			*outDidModify = YES;
		}

		return (driveList);
	}];
}

- (void)unsubscribeFromDrives:(NSArray<OCDrive *> *)drives
{
	[self _modifyDriveListWith:^OCVaultDriveList *(OCVaultDriveList *driveList, BOOL *outDidModify) {
		NSUInteger count = driveList.subscribedDriveIDs.count;

		for (OCDrive *drive in drives)
		{
			[driveList.subscribedDriveIDs removeObject:drive.identifier];
		}

		if (count != driveList.subscribedDriveIDs.count)
		{
			OCTLogDebug(@[@"Drives"], @"Unsubscribed from drives: %@", drives);
			*outDidModify = YES;
		}

		return (driveList);
	}];
}

- (void)changeDetachedState:(OCDriveDetachedState)detachedState forDriveID:(OCDriveID)detachedDriveID
{
	[self _modifyDriveListWith:^OCVaultDriveList *(OCVaultDriveList *driveList, BOOL *outDidModify) {

		OCDrive *modifyDrive = [driveList.detachedDrives firstObjectMatching:^BOOL(OCDrive * _Nonnull drive) {
			return ([drive.identifier isEqual:detachedDriveID]);
		}];

		if (modifyDrive != nil)
		{
			OCTLogDebug(@[@"Drives"], @"Changed detachedState to %ld for drive: %@", (long)detachedState, modifyDrive);

			modifyDrive.detachedState = detachedState;
			*outDidModify = YES;
		}

		return (driveList);
	}];
}

- (nullable OCDrive *)driveWithIdentifier:(OCDriveID)driveID
{
	OCDrive *drive;

	@synchronized(self)
	{
		if ((drive = _activeDrivesByID[driveID]) == nil)
		{
			drive = _detachedDrivesByID[driveID];
		}
	}

	return (drive);
}

- (void)startDriveUpdates
{
	if (!_observingDrivesUpdates)
	{
		__weak OCVault *weakSelf = self;
		__block BOOL isInitial = YES;

		_observingDrivesUpdates = YES;

		OCTLogDebug(@[@"Drives"], @"Starting drive update observation for bookmark: %@", _bookmark);

		[self.keyValueStore addObserver:^(OCKeyValueStore * _Nonnull store, id  _Nullable owner, OCKeyValueStoreKey  _Nonnull key, OCVaultDriveList * _Nullable driveList) {
			[weakSelf _updateFromDriveList:driveList];

			if (isInitial)
			{
				isInitial = NO;
			}
			else
			{
				dispatch_async(dispatch_get_main_queue(), ^{
					[NSNotificationCenter.defaultCenter postNotificationName:OCVaultDriveListChanged object:weakSelf];
				});
			}
		} forKey:OCKeyValueStoreKeyVaultDriveList withOwner:self initial:YES];
	}
}

- (void)stopDriveUpdates
{
	if (_observingDrivesUpdates)
	{
		_observingDrivesUpdates = NO;
		[self.keyValueStore removeObserverForOwner:self forKey:OCKeyValueStoreKeyVaultDriveList];

		OCTLogDebug(@[@"Drives"], @"Stopped drive update observation for bookmark: %@", _bookmark);
	}
}

- (void)_modifyDriveListWith:(OCVaultDriveList *(^)(OCVaultDriveList *driveList, BOOL *outDidModify))driveListModifier
{
	__block OCVaultDriveList *updateFromDriveList = nil;

	[self.keyValueStore updateObjectForKey:OCKeyValueStoreKeyVaultDriveList usingModifier:^id _Nullable(OCVaultDriveList *driveList, BOOL * _Nonnull outDidModify) {
		if (driveList == nil)
		{
			driveList = [OCVaultDriveList new];
		}

		BOOL didModify = NO;
		OCVaultDriveList *newDriveList = driveListModifier(driveList, &didModify);

		if (didModify)
		{
			updateFromDriveList = newDriveList;
		}

		*outDidModify = didModify;
		return (newDriveList);
	}];

	if (updateFromDriveList != nil)
	{
		[self _updateFromDriveList:updateFromDriveList];
	}
}

- (void)_updateFromDriveList:(OCVaultDriveList *)driveList
{
	[self willChangeValueForKey:@"activeDrives"];
	[self willChangeValueForKey:@"subscribedDrives"];
	[self willChangeValueForKey:@"detachedDrives"];

	@synchronized(self)
	{
		_activeDrives = driveList.drives;
		_activeDrivesByID = [_activeDrives dictionaryUsingMapper:^OCDriveID(OCDrive *drive) {
			return (drive.identifier);
		}];

		_subscribedDrives = [driveList.drives filteredArrayUsingBlock:^BOOL(OCDrive * _Nonnull drive, BOOL * _Nonnull stop) {
			return ([driveList.subscribedDriveIDs containsObject:drive.identifier]);
		}];

		_detachedDrives = driveList.detachedDrives;
		_detachedDrivesByID = [_detachedDrives dictionaryUsingMapper:^OCDriveID(OCDrive *drive) {
			return (drive.identifier);
		}];
	}

	[self didChangeValueForKey:@"detachedDrives"];
	[self didChangeValueForKey:@"subscribedDrives"];
	[self didChangeValueForKey:@"activeDrives"];
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

			[self startDriveUpdates];

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
	[self stopDriveUpdates];

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

#pragma mark - URL/path parser
+ (nullable OCVaultLocation *)locationForURL:(NSURL *)url
{
	OCVaultLocation *location = nil;
	NSString *urlPath = url.path;
	NSString *storageRootPath = OCVault.storageRootURL.path.normalizedDirectoryPath;

	if (![urlPath hasPrefix:storageRootPath])
	{
		// URL not in file provider's storage root path
		return (nil);
	}

	NSString *relativePath = [urlPath substringFromIndex:storageRootPath.length];
	NSArray<NSString *> *pathComponents = relativePath.pathComponents;

	if (pathComponents.count > 0)
	{
		if ([pathComponents.firstObject isEqual:OCVaultPathVFS])
		{
			// Possible layouts:
		}
		else
		{
			// Possible layouts:
			// [Bookmark UUID]/[Local ID]/[filename.xyz]
			// [Bookmark UUID]/Drives/[Drive ID]/[Local ID]/[filename.xyz]
			const NSUInteger uuidStringLength = 36;
			NSUInteger parsedElements = 0;

			if (pathComponents[0].length == uuidStringLength) // [Bookmark UUID]/…
			{
				location = [OCVaultLocation new];

				location.bookmarkUUID = [[NSUUID alloc] initWithUUIDString:pathComponents[0]];
				parsedElements = 1;

				if (pathComponents.count > 1)
				{
					if ([pathComponents[1] isEqual:OCVaultPathVFS]) // [Bookmark UUID]/VFS/…
					{
						parsedElements = 2;
						if (pathComponents.count > 2)
						{
							location.vfsNodeID = pathComponents[2]; // [Bookmark UUID]/VFS/[VFS Node ID]/…
							parsedElements = 3;

							if (pathComponents.count > 3) // && (pathComponents[3].length == uuidStringLength)) // [Bookmark UUID]/Drives/[Drive ID]/[Local ID]/…
							{
								location.localID = pathComponents[3];
								parsedElements = 4;
							}
						}
					}

					if ([pathComponents[1] isEqual:OCVaultPathDrives]) // [Bookmark UUID]/Drives/…
					{
						parsedElements = 2;
						if (pathComponents.count > 2)
						{
							location.driveID = pathComponents[2]; // [Bookmark UUID]/Drives/[Drive ID]/…
							parsedElements = 3;

							// if ((pathComponents.count > 3) && (pathComponents[3].length == uuidStringLength)) // [Bookmark UUID]/Drives/[Drive ID]/[Local ID]/…
							if (pathComponents.count > 3) // [Bookmark UUID]/Drives/[Drive ID]/[Local ID]/…
							{
								location.localID = pathComponents[3];
								parsedElements = 4;
							}
							else
							{
								// [Bookmark UUID]/Drives/[Drive ID] is virtual
								location.isVirtual = YES;
							}
						}
					}
					else // if (pathComponents[1].length == uuidStringLength) // [Bookmark UUID]/[Local ID]/…
					{
						location.localID = pathComponents[1];
						parsedElements = 2;
					}
				}

				if (pathComponents.count > parsedElements)
				{
					location.additionalPathElements = [pathComponents subarrayWithRange:NSMakeRange(parsedElements, pathComponents.count - parsedElements)];
				}
			}
		}
	}

	return (location);
}

+ (nullable NSURL *)urlForLocation:(OCVaultLocation *)location
{
	NSURL *returnURL = nil;

	if (location.isVirtual)
	{
		// VFS Node
		if (location.vfsNodeID != nil)
		{
			// VFS/[VFS Node ID]
			// [Bookmark UUID]VFS/[VFS Node ID]
			returnURL = [[self vfsStorageRootURLForBookmarkUUID:location.bookmarkUUID] URLByAppendingPathComponent:location.vfsNodeID];
		}
		else if ((location.bookmarkUUID != nil) && (location.driveID != nil))
		{
			// [Bookmark UUID]/Drives/[Drive ID]
			returnURL = [[[self storageRootURLForBookmarkUUID:location.bookmarkUUID] URLByAppendingPathComponent:OCVaultPathDrives isDirectory:YES] URLByAppendingPathComponent:location.driveID isDirectory:YES];
		}
	}
	else if ((location.bookmarkUUID != nil) && (location.localID != nil))
	{
		// Item location
		if (location.driveID != nil)
		{
			// Drive-based: [storageRoot]/Drives/[LocalID]/…
			returnURL = [[[[self storageRootURLForBookmarkUUID:location.bookmarkUUID] URLByAppendingPathComponent:OCVaultPathDrives isDirectory:YES] URLByAppendingPathComponent:location.driveID isDirectory:YES] URLByAppendingPathComponent:location.localID isDirectory:YES];
		}
		else
		{
			// OC10 based: [storageRoot]/[LocalID]/…
			returnURL = [[self storageRootURLForBookmarkUUID:location.bookmarkUUID] URLByAppendingPathComponent:location.localID isDirectory:YES];
		}
	}

	if ((returnURL != nil) && (location.additionalPathElements.count > 0))
	{
		// Append (additional) path elements
		returnURL = [returnURL URLByAppendingPathComponent:[location.additionalPathElements componentsJoinedByString:@"/"] isDirectory:NO];
	}

	return (returnURL);
}

@end

NSString *OCVaultPathVaults = @"Vaults";
NSString *OCVaultPathHTTPPipeline = @"HTTPPipeline";
NSString *OCVaultPathDrives = @"Drives";
NSString *OCVaultPathVFS = @"VFS";

OCKeyValueStoreKey OCKeyValueStoreKeyVaultDriveList = @"vaultDriveList";

NSNotificationName OCVaultDriveListChanged = @"OCVaultDriveListChanged";
