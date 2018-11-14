//
//  OCCore+CommandLocalModification.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 02.08.18.
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

#import "OCCore.h"
#import "OCSyncActionUpload.h"
#import "OCItem+OCFileURLMetadata.h"

@implementation OCCore (CommandLocalModification)

#pragma mark - Command
- (nullable NSProgress *)reportLocalModificationOfItem:(OCItem *)item parentItem:(OCItem *)parentItem withContentsOfFileAtURL:(nullable NSURL *)inputFileURL isSecurityScoped:(BOOL)isSecurityScoped options:(nullable NSDictionary *)options placeholderCompletionHandler:(nullable OCCorePlaceholderCompletionHandler)placeholderCompletionHandler resultHandler:(nullable OCCoreUploadResultHandler)resultHandler
{
	NSError *error = nil, *criticalError = nil;
	NSURL *itemFileURL, *temporaryFileURL;

	// Required parameters
	if (item == nil) { return(nil); }

	if (((itemFileURL = [self.vault localURLForItem:item]) != nil) &&
	    ((temporaryFileURL = [self availableTemporaryURLAlongsideItem:item fileName:NULL]) != nil))
	{
		BOOL proceed = YES;

		// Use itemFileURL if no inputFileURL was provided
		if (inputFileURL == nil)
		{
			inputFileURL = itemFileURL;
		}

		// Copy file into the vault for uploading
		if (isSecurityScoped)
		{
			proceed = [inputFileURL startAccessingSecurityScopedResource];
		}

		if (proceed)
		{
			// Copy input file to temporary copy location (utilizing APFS cloning, this should be both almost instant as well as cost no actual disk space thanks to APFS copy-on-write)
			if (![[NSFileManager defaultManager] copyItemAtURL:inputFileURL toURL:temporaryFileURL error:&error])
			{
				OCLogError(@"Local modification for item %@ from %@ to %@ failed in temp-copy phase with error: ", OCLogPrivate(item), OCLogPrivate(inputFileURL), OCLogPrivate(temporaryFileURL), OCLogPrivate(error));
				criticalError = error;
				proceed = NO;
			}
			else
			{
				// Update file at item location with input file
				if (![inputFileURL isEqual:itemFileURL])
				{
					// Input file and item file differ

					// Remove existing file at item location
					if ([[NSFileManager defaultManager] fileExistsAtPath:itemFileURL.path])
					{
						if (![[NSFileManager defaultManager] removeItemAtURL:itemFileURL error:&error])
						{
							OCLogError(@"Local modification for item %@ from %@ to %@ failed in delete old phase with error: ", OCLogPrivate(item), OCLogPrivate(temporaryFileURL), OCLogPrivate(itemFileURL), OCLogPrivate(error));
						}
					}

					// Copy file to placeholder item location (for the fileprovider and others working with the item), (utilizing APFS cloning, this should be both almost instant as well as cost no actual disk space thanks to APFS copy-on-write)
					if (![[NSFileManager defaultManager] copyItemAtURL:temporaryFileURL toURL:itemFileURL error:&error])
					{
						OCLogError(@"Local modification for item %@ from %@ to %@ failed in copy phase with error: ", OCLogPrivate(item), OCLogPrivate(temporaryFileURL), OCLogPrivate(itemFileURL), OCLogPrivate(error));
						criticalError = error;
						proceed = NO;
					}
				}
			}

			if (isSecurityScoped)
			{
				[inputFileURL stopAccessingSecurityScopedResource];
			}
		}

		if (proceed)
		{
			// Update metadata from input file
			[item updateMetadataFromFileURL:itemFileURL];

			item.localRelativePath = [self.vault relativePathForItem:item];
			item.locallyModified = YES; // Unsynced yet, so it's a local modification. Also prevents pruning before upload finishes.
		}
	}
	else
	{
		OCLogError(@"Local modification failed because core %@ -localURLForItem for item %@ returned nil", self, OCLogPrivate(item));
		criticalError = OCError(OCErrorInternal);
	}

	if (criticalError != nil)
	{
		// Handle critical errors
		if (placeholderCompletionHandler != nil)
		{
			placeholderCompletionHandler(criticalError, nil);
		}

		if (resultHandler != nil)
		{
			resultHandler(criticalError, self, nil, nil);
		}

		return (nil);
	}
	else
	{
		// Invoke placeholder completion handler
		if (placeholderCompletionHandler != nil)
		{
			placeholderCompletionHandler(nil, item);
		}
	}

	// Enqueue sync record
	return ([self _enqueueSyncRecordWithAction:[[OCSyncActionUpload alloc] initWithUploadItem:item parentItem:parentItem filename:item.name importFileURL:temporaryFileURL isTemporaryCopy:YES] allowsRescheduling:NO resultHandler:resultHandler]);
}

@end
