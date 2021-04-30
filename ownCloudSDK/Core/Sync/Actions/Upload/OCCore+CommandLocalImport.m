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
#import "OCSyncActionUpload.h"
#import "OCItem+OCFileURLMetadata.h"
#import "OCCore+NameConflicts.h"

#import <CoreServices/CoreServices.h>

@implementation OCCore (CommandLocalImport)

#pragma mark - Command
- (nullable NSProgress *)importFileNamed:(nullable NSString *)newFileName at:(OCItem *)parentItem fromURL:(NSURL *)inputFileURL isSecurityScoped:(BOOL)isSecurityScoped options:(nullable NSDictionary<OCCoreOption,id> *)options placeholderCompletionHandler:(nullable OCCorePlaceholderCompletionHandler)placeholderCompletionHandler resultHandler:(nullable OCCoreUploadResultHandler)resultHandler
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

	// Alternative name pick
	NSNumber *nameStyleNumber = nil;

	if ((nameStyleNumber = options[OCCoreOptionAutomaticConflictResolutionNameStyle]) != nil)
	{
		if (nameStyleNumber.integerValue != OCCoreDuplicateNameStyleNone)
		{
			__block NSString *outSuggestedName = nil;

			OCSyncExec(checkForExistingItems, {
				[self suggestUnusedNameBasedOn:newFileName atPath:parentItem.path isDirectory:NO usingNameStyle:nameStyleNumber.unsignedIntegerValue filteredBy:nil resultHandler:^(NSString * _Nullable suggestedName, NSArray<NSString *> * _Nullable rejectedAndTakenNames) {
					outSuggestedName = suggestedName;
					OCSyncExecDone(checkForExistingItems);
				}];
			});

			if (outSuggestedName != nil)
			{
				newFileName = outSuggestedName;
			}
		}
	}

	// Create placeholder item and fill fields required by -[NSFileProviderExtension importDocumentAtURL:toParentItemIdentifier:completionHandler:] completion handler
	placeholderItem = [OCItem placeholderItemOfType:OCItemTypeFile];

	placeholderItem.parentLocalID = parentItem.localID;
	placeholderItem.parentFileID = parentItem.fileID;
	placeholderItem.path = [parentItem.path stringByAppendingPathComponent:newFileName];

	// Move file into the vault for uploading
	if ((placeholderOutputURL = [self.vault localURLForItem:placeholderItem]) != nil)
	{
		BOOL relinquishSecurityScopedResourceAccess = NO;

		if (isSecurityScoped)
		{
			relinquishSecurityScopedResourceAccess = [inputFileURL startAccessingSecurityScopedResource];
		}

		// Update metadata from input file
		[placeholderItem updateMetadataFromFileURL:inputFileURL];

		// Create directory for placeholder item
		if ((error = [self createDirectoryForItem:placeholderItem]) != nil)
		{
			OCLogError(@"Local creation target directory creation failed for %@ with error %@", OCLogPrivate(placeholderItem), error);
		}

		// Move file to placeholder item location
		BOOL importFileOperationSuccessful;

		if (((NSNumber *)options[OCCoreOptionImportByCopying]).boolValue)
		{
			// Import by copy
			importFileOperationSuccessful = [[NSFileManager defaultManager] copyItemAtURL:inputFileURL toURL:placeholderOutputURL error:&error];
			OCFileOpLog(@"cp", error, @"Importing by copy %@ as %@", inputFileURL.path, placeholderOutputURL.path);
		}
		else
		{
			// Import by moving
			importFileOperationSuccessful = [[NSFileManager defaultManager] moveItemAtURL:inputFileURL toURL:placeholderOutputURL error:&error];
			OCFileOpLog(@"mv", error, @"Importing by moving %@ as %@", inputFileURL.path, placeholderOutputURL.path);
		}

		if (importFileOperationSuccessful)
		{
			// Check for and apply transformations
			OCCoreImportTransformation transformation;

			if ((transformation = options[OCCoreOptionImportTransformation]) != nil)
			{
				NSError *transformationError;

				OCLogDebug(@"Transforming transformation on item %@", OCLogPrivate(placeholderItem));

				if ((transformationError = transformation(placeholderOutputURL)) == nil)
				{
					OCLogDebug(@"Transformation succeeded on item %@", OCLogPrivate(placeholderItem));
					[placeholderItem updateMetadataFromFileURL:placeholderOutputURL];
				}
				else
				{
					OCLogDebug(@"Transformation failed with error=%@ on item %@", transformationError, OCLogPrivate(placeholderItem));
					error = transformationError;
					importFileOperationSuccessful = NO;
				}

				// Remove transformation block from options dictionary
				NSMutableDictionary<OCCoreOption,id> *mutableOptions;

				if ((mutableOptions = [options mutableCopy]) != nil)
				{
					mutableOptions[OCCoreOptionImportTransformation] = nil;
					options = mutableOptions;
				}
			}
		}

		if (importFileOperationSuccessful)
		{
			placeholderItem.localRelativePath = [self.vault relativePathForItem:placeholderItem];
			placeholderItem.localCopyVersionIdentifier = nil;
			placeholderItem.locallyModified = YES; // Since this file exists local-only, it's "a local modification". Also prevents pruning before upload finishes.
		}
		else
		{
			OCLogError(@"Local creation for item %@ from %@ to %@ failed in move phase with error: %@", OCLogPrivate(placeholderItem), OCLogPrivate(inputFileURL), OCLogPrivate(placeholderOutputURL), OCLogPrivate(error));
			criticalError = error;
		}

		if (isSecurityScoped && relinquishSecurityScopedResourceAccess)
		{
			[inputFileURL stopAccessingSecurityScopedResource];
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

	// Override last modified date (if provided as option)
	NSDate *lastModifiedOverrideDate;

	if ((lastModifiedOverrideDate = OCTypedCast(options[OCCoreOptionLastModifiedDate], NSDate)) != nil)
	{
		placeholderItem.lastModified = lastModifiedOverrideDate;
	}

	// Enqueue sync record
	NSProgress *progress;

	progress = [self _enqueueSyncRecordWithAction:[[OCSyncActionUpload alloc] initWithUploadItem:placeholderItem parentItem:parentItem filename:newFileName importFileURL:placeholderOutputURL isTemporaryCopy:NO options:options] cancellable:YES preflightResultHandler:^(NSError * _Nullable error) {
		// Invoke placeholder completion handler - AFTER it was added to the database as part of preflight
		if (placeholderCompletionHandler != nil)
		{
			placeholderCompletionHandler(error, placeholderItem);
		}
	} resultHandler:resultHandler];

	return (progress);
}

@end
