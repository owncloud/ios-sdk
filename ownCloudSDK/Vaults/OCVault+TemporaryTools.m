//
//  OCVault+TemporaryTools.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 26.02.25.
//  Copyright © 2025 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2025, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCVault+TemporaryTools.h"

@implementation OCVault (TemporaryTools)

- (nullable OCVaultTemporaryStorageEraser)createTemporaryUploadContainer:(NSURL ** _Nullable)outURL error:(NSError * _Nullable * _Nullable)outError
{
	NSURL *parentURL = self.temporaryUploadURL;
	NSURL *temporaryDirectoryURL = [parentURL URLByAppendingPathComponent:NSUUID.UUID.UUIDString];
	NSError *error = nil;
	OCVaultTemporaryStorageEraser eraser = nil;

	if ([NSFileManager.defaultManager createDirectoryAtURL:temporaryDirectoryURL withIntermediateDirectories:YES attributes:@{ NSFileProtectionKey : NSFileProtectionCompleteUntilFirstUserAuthentication } error:&error])
	{
		eraser = ^{
			[NSFileManager.defaultManager removeItemAtURL:temporaryDirectoryURL error:NULL];
		};
	}

	if (outURL != NULL) {
		*outURL = (error == nil) ? temporaryDirectoryURL : nil;
	}

	if (outError != NULL) {
		*outError = error;
	}

	return ([eraser copy]);
}

- (nullable OCVaultTemporaryStorageEraser)createTemporaryUploadFileFromData:(NSData *)data name:(NSString *)name url:(NSURL * _Nonnull * _Nullable)outURL error:(NSError * _Nullable * _Nullable)outError
{
	NSURL *containerURL = nil;
	NSError *error = nil;
	OCVaultTemporaryStorageEraser tempFolderEraser;
	OCVaultTemporaryStorageEraser eraser = nil;

	if ((tempFolderEraser = [self createTemporaryUploadContainer:&containerURL error:&error]) != nil)
	{
		NSURL *tempFileURL = [containerURL URLByAppendingPathComponent:name];
		if ([data writeToURL:tempFileURL options:NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication error:&error])
		{
			if (outURL != NULL) {
				*outURL = tempFileURL;
			}
			eraser = tempFolderEraser;
		}
		else
		{
			tempFolderEraser();
		}
	}

	if (outError != NULL) {
		*outError = error;
	}

	return (eraser);
}

@end
