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
#import "OCSyncActionLocalImport.h"

#import <MobileCoreServices/MobileCoreServices.h>

@implementation OCCore (CommandLocalImport)

#pragma mark - Command
- (NSProgress *)importFileNamed:(NSString *)newFileName at:(OCItem *)parentItem fromURL:(NSURL *)inputFileURL isSecurityScoped:(BOOL)isSecurityScoped options:(NSDictionary *)options placeholderCompletionHandler:(OCCorePlaceholderCompletionHandler)placeholderCompletionHandler resultHandler:(OCCoreUploadResultHandler)resultHandler
{
	NSNumber *filesize = nil;
	NSString *typeIdentifier = nil;
	NSError *error = nil, *criticalError = nil;
	NSDate *creationDate = nil,  *lastModified = nil;
	NSURL *outputURL;

	OCItem *placeholderItem;

	// Required parameters
	if (parentItem == nil)   { return(nil); }
	if (inputFileURL == nil) { return(nil); }

	// Determine name of new file from localFileURL if none was given
	if (newFileName == nil)
	{
		newFileName = inputFileURL.lastPathComponent;
	}

	// Get metadata from input file
	[inputFileURL getResourceValue:&filesize forKey:NSURLFileSizeKey error:&error];
	[inputFileURL getResourceValue:&creationDate forKey:NSURLCreationDateKey error:&error];
	[inputFileURL getResourceValue:&lastModified forKey:NSURLContentModificationDateKey error:&error];
	[inputFileURL getResourceValue:&typeIdentifier forKey:NSURLTypeIdentifierKey error:&error];

	// Create placeholder item and fill fields required by -[NSFileProviderExtension importDocumentAtURL:toParentItemIdentifier:completionHandler:] completion handler
	placeholderItem = [OCItem placeholderItemOfType:OCItemTypeFile];

	placeholderItem.parentFileID = parentItem.fileID;
	placeholderItem.path = [parentItem.path stringByAppendingPathComponent:newFileName];
	placeholderItem.fileID = [OCFileIDPlaceholderPrefix stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
	placeholderItem.eTag = OCFileETagPlaceholder;

	placeholderItem.creationDate = creationDate;
	placeholderItem.lastModified = lastModified;
	placeholderItem.size = filesize.integerValue;

	if (typeIdentifier != nil)
	{
		placeholderItem.mimeType = ((NSString *)CFBridgingRelease(UTTypeCopyPreferredTagWithClass((__bridge CFStringRef _Nonnull)(typeIdentifier), kUTTagClassMIMEType)));
	}

	// Move file into the vault for uploading
	if ((outputURL = [self.vault localURLForItem:placeholderItem]) != nil)
	{
		BOOL proceed = YES;

		if (isSecurityScoped)
		{
			proceed = [inputFileURL startAccessingSecurityScopedResource];
		}

		if (proceed)
		{
			if (![[NSFileManager defaultManager] fileExistsAtPath:[[outputURL URLByDeletingLastPathComponent] path]]) // This should always be true since its supposed to be a new file
			{
				if (![[NSFileManager defaultManager] createDirectoryAtURL:[outputURL URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error])
				{
					OCLogError(@"Local creation target directory creation failed for %@ with error %@", OCLogPrivate(outputURL), error);
				}
			}
			else
			{
				OCLogWarning(@"Local creation target directory already exists for %@", OCLogPrivate(outputURL));
			}

			if ([[NSFileManager defaultManager] moveItemAtURL:inputFileURL toURL:outputURL error:&error])
			{
				placeholderItem.localRelativePath = [self.vault relativePathForItem:placeholderItem];
			}
			else
			{
				OCLogError(@"Local creation for item %@ from %@ to %@ failed in move phase with error: ", OCLogPrivate(placeholderItem), OCLogPrivate(inputFileURL), OCLogPrivate(outputURL), OCLogPrivate(error));
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
	return ([self _enqueueSyncRecordWithAction:[[OCSyncActionLocalImport alloc] initWithParentItem:parentItem filename:newFileName importFileURL:outputURL placeholderItem:placeholderItem] allowsRescheduling:NO resultHandler:resultHandler]);
}

@end
