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

@interface OCVault () <NSFileManagerDelegate>
@end

@implementation OCVault

@synthesize uuid = _uuid;

@synthesize rootURL = _rootURL;
@synthesize databaseURL = _databaseURL;
@synthesize filesRootURL = _filesRootURL;

@synthesize database = _database;

#pragma mark - Init
- (instancetype)init
{
	return (nil);
}

- (instancetype)initWithBookmark:(OCBookmark *)bookmark
{
	if ((self = [super init]) != nil)
	{
		_uuid = bookmark.uuid;
	}
	
	return (self);
}

- (NSURL *)rootURL
{
	if (_rootURL == nil)
	{
		_rootURL = [[[[OCAppIdentity sharedAppIdentity] appGroupContainerURL] URLByAppendingPathComponent:OCVaultPathVaults] URLByAppendingPathComponent:[OCVault rootPathRelativeToGroupContainerForVaultUUID:_uuid]];
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

- (NSURL *)filesRootURL
{
	if (_filesRootURL == nil)
	{
		_filesRootURL = [[NSFileProviderManager defaultManager].documentStorageURL URLByAppendingPathComponent:[_uuid UUIDString]];
	}

	return (_filesRootURL);
}

- (NSURL *)connectionDataRootURL
{
	if (_connectionDataRootURL == nil)
	{
		_connectionDataRootURL = [self.rootURL URLByAppendingPathComponent:OCVaultPathConnectionData];
	}

	return (_connectionDataRootURL);
}

- (OCDatabase *)database
{
	if (_database == nil)
	{
		_database = [[OCDatabase alloc] initWithURL:self.databaseURL];
	}

	return (_database);
}

#pragma mark - Operations
- (void)openWithCompletionHandler:(OCCompletionHandler)completionHandler
{
	NSError *error = nil;

	if ([[NSFileManager defaultManager] createDirectoryAtURL:self.rootURL withIntermediateDirectories:YES attributes:nil error:&error])
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

- (void)eraseWithCompletionHandler:(OCCompletionHandler)completionHandler
{
	if (self.rootURL != nil)
	{
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
			NSError *error = nil;

			NSFileManager *fileManager = [NSFileManager new];

			fileManager.delegate = self;

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

- (BOOL)fileManager:(NSFileManager *)fileManager shouldRemoveItemAtURL:(NSURL *)URL
{
	return (YES);
}

#pragma mark - URL and path builders
- (NSURL *)localURLForItem:(OCItem *)item
{
	// Build the URL to where an item should be stored. Follow <filesRootURL>/<fileID>/<fileName> pattern.
	return ([[self.filesRootURL URLByAppendingPathComponent:item.fileID isDirectory:YES] URLByAppendingPathComponent:item.name isDirectory:NO]);
}

+ (NSString *)rootPathRelativeToGroupContainerForVaultUUID:(NSUUID *)uuid
{
	return (uuid.UUIDString);
}

+ (NSString *)databaseFilePathRelativeToRootPathForVaultUUID:(NSUUID *)uuid
{
	return ([uuid.UUIDString stringByAppendingString:@".db"]);
}

@end

NSString *OCVaultPathVaults = @"Vaults";
NSString *OCVaultPathFiles = @"Files";
NSString *OCVaultPathConnectionData = @"ConnectionData";

