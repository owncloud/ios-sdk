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
#import "OCCore+SyncEngine.h"

@implementation OCVault

@synthesize uuid = _uuid;

@synthesize rootURL = _rootURL;
@synthesize databaseURL = _databaseURL;
@synthesize keyValueStoreURL = _keyValueStoreURL;
@synthesize filesRootURL = _filesRootURL;

@synthesize database = _database;
@synthesize keyValueStore = _keyValueStore;

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

	if (!didAutoDetectFromInfoPlist)
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

		_fileProviderSignalCountByContainerItemIdentifiers = [NSMutableDictionary new];
		_fileProviderSignalCountByContainerItemIdentifiersLock = @"_fileProviderSignalCountByContainerItemIdentifiersLock";
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

- (NSURL *)filesRootURL
{
	if (_filesRootURL == nil)
	{
		if (OCVault.hostHasFileProvider)
		{
			_filesRootURL = [[NSFileProviderManager defaultManager].documentStorageURL URLByAppendingPathComponent:[_uuid UUIDString]];
		}
		else
		{
			_filesRootURL = [self.rootURL URLByAppendingPathComponent:@"Files"];
		}
	}

	return (_filesRootURL);
}

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
		_keyValueStore = [[OCKeyValueStore alloc] initWithURL:self.keyValueStoreURL identifier:self.uuid.UUIDString];
		[_keyValueStore registerClass:[OCEventQueue class] forKey:OCKeyValueStoreKeyOCCoreSyncEventsQueue];
	}

	return (_keyValueStore);
}

#pragma mark - Operations
- (void)openWithCompletionHandler:(OCCompletionHandler)completionHandler
{
	NSError *error = nil;

	if ([[NSFileManager defaultManager] createDirectoryAtURL:self.rootURL withIntermediateDirectories:YES attributes:@{ NSFileProtectionKey : NSFileProtectionCompleteUntilFirstUserAuthentication } error:&error])
	{
		[self.database openWithCompletionHandler:^(OCDatabase *db, NSError *error) {
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
			}

			if (completionHandler != nil)
			{
				completionHandler(self, error);
			}
		});
	}
}

#pragma mark - URL and path builders
- (NSURL *)localURLForItem:(OCItem *)item
{
	// Build the URL to where an item should be stored. Follow <filesRootURL>/<localID>/<fileName> pattern.
	return ([self.filesRootURL URLByAppendingPathComponent:[self relativePathForItem:item] isDirectory:NO]);
}

- (NSURL *)localFolderURLForItem:(OCItem *)item
{
	// Build the URL to where an item's folder should be stored. Follows <filesRootURL>/<localID>/ pattern.
	return ([self.filesRootURL URLByAppendingPathComponent:item.localID isDirectory:YES]);
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

@end

NSString *OCVaultPathVaults = @"Vaults";
NSString *OCVaultPathHTTPPipeline = @"HTTPPipeline";

