//
//  OCCore+CommandLocalImport.m
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
#import "OCCore+SyncEngine.h"
#import "OCSyncContext.h"
#import "NSError+OCError.h"
#import "OCMacros.h"
#import "NSString+OCParentPath.h"
#import "OCLogger.h"
#import "OCCore+FileProvider.h"
#import "OCSyncActionUpload.h"
#import "OCItem+OCFileURLMetadata.h"

#import <MobileCoreServices/MobileCoreServices.h>

@implementation OCCore (CommandLocalImport)

#pragma mark - Command
- (nullable NSProgress *)importFileNamed:(nullable NSString *)newFileName at:(OCItem *)parentItem fromURL:(NSURL *)inputFileURL isSecurityScoped:(BOOL)isSecurityScoped options:(nullable NSDictionary *)options placeholderCompletionHandler:(nullable OCCorePlaceholderCompletionHandler)placeholderCompletionHandler resultHandler:(nullable OCCoreUploadResultHandler)resultHandler
{
	NSError *error = nil, *criticalError = nil;
	NSURL *placeholderOutputURL;

	OCItem *placeholderItem;

	// Required parameters
	if (parentItem == nil)   { return(nil); }
	if (inputFileURL == nil) { return(nil); }

	// Determine name of new file from localFileURL if none was given
	if (newFileName == nil)
	{
		newFileName = inputFileURL.lastPathComponent;
	}

	// Create placeholder item and fill fields required by -[NSFileProviderExtension importDocumentAtURL:toParentItemIdentifier:completionHandler:] completion handler
	placeholderItem = [OCItem placeholderItemOfType:OCItemTypeFile];

	placeholderItem.parentFileID = parentItem.fileID;
	placeholderItem.path = [parentItem.path stringByAppendingPathComponent:newFileName];

	// Move file into the vault for uploading
	if ((placeholderOutputURL = [self.vault localURLForItem:placeholderItem]) != nil)
	{
		BOOL proceed = YES;

		if (isSecurityScoped)
		{
			proceed = [inputFileURL startAccessingSecurityScopedResource];
		}

		if (proceed)
		{
			// Update metadata from input file
			[placeholderItem updateMetadataFromFileURL:inputFileURL];

			// Create directory for placeholder item
			if ((error = [self createDirectoryForItem:placeholderItem]) != nil)
			{
				OCLogError(@"Local creation target directory creation failed for %@ with error %@", OCLogPrivate(placeholderItem), error);
			}

			// Move file to placeholder item location
			if ([[NSFileManager defaultManager] moveItemAtURL:inputFileURL toURL:placeholderOutputURL error:&error])
			{
				placeholderItem.localRelativePath = [self.vault relativePathForItem:placeholderItem];
				placeholderItem.locallyModified = YES; // Since this file exists local-only, it's "a local modification". Also prevents pruning before upload finishes.
			}
			else
			{
				OCLogError(@"Local creation for item %@ from %@ to %@ failed in move phase with error: ", OCLogPrivate(placeholderItem), OCLogPrivate(inputFileURL), OCLogPrivate(placeholderOutputURL), OCLogPrivate(error));
				criticalError = error;
			}

			if (isSecurityScoped)
			{
				[inputFileURL stopAccessingSecurityScopedResource];
			}
		}
	}
	else
	{
		OCLogError(@"Local creation failed because core %@ -localURLForItem for item %@ returned nil", self, OCLogPrivate(placeholderItem));
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
			placeholderCompletionHandler(nil, placeholderItem);
		}
	}

	// Enqueue sync record
	return ([self _enqueueSyncRecordWithAction:[[OCSyncActionUpload alloc] initWithUploadItem:placeholderItem parentItem:parentItem filename:newFileName importFileURL:placeholderOutputURL isTemporaryCopy:NO] allowsRescheduling:NO resultHandler:resultHandler]);
}

@end
