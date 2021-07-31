//
//  OCVault+Prepopulation.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.06.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCConnection.h"
#import "OCHTTPDAVRequest.h"
#import "OCVault+Prepopulation.h"
#import "NSProgress+OCExtensions.h"
#import "NSString+OCPath.h"
#import "OCDatabase.h"
#import "NSError+OCError.h"
#import "OCCoreDirectoryUpdateJob.h"

@implementation OCVault (Prepopulation)

- (NSURL *)davRawResponseFolderURL
{
	return ([self.rootURL URLByAppendingPathComponent:@"davRawResponses" isDirectory:YES]);
}

- (NSError *)eraseDavRawResponses
{
	NSError *error = nil;
	NSURL *davRawResponseFolderURL;

	if ((davRawResponseFolderURL = [self davRawResponseFolderURL]) != nil)
	{
		if (![NSFileManager.defaultManager removeItemAtURL:davRawResponseFolderURL error:&error])
		{
			return (error);
		}
	}

	return (nil);
}

- (nullable NSProgress *)prepopulateDatabaseWithRawResponse:(OCDAVRawResponse *)davRawResponse progressHandler:(nullable void(^)(NSUInteger folderCount, NSUInteger fileCount))progressHandler completionHandler:(void (^)(NSError *_Nullable error))completionHandler
{
	return ([self _prepopulateDatabaseWithXMLParserProvider:^OCXMLParser *{
		OCXMLParser *parser = nil;
		NSMutableDictionary<NSString *,OCUser *> *usersByUserID = [NSMutableDictionary new];

		// -- TEST CODE: cut off XML at half
		// NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingToURL:davRawResponse.responseDataURL error:NULL];
		//
		// [fileHandle seekToEndOfFile];
		// NSUInteger length = fileHandle.offsetInFile;
		// [fileHandle truncateAtOffset:(length/2) error:NULL];
		//
		// fileHandle = nil;
		// -- END TEST CODE

		if ((parser = [[OCXMLParser alloc] initWithURL:davRawResponse.responseDataURL]) != nil)
		{
			parser.options = [NSMutableDictionary dictionaryWithObjectsAndKeys:
				davRawResponse.basePath, 	@"basePath",
				usersByUserID, 			@"usersByUserID",
			nil];
		}

		return (parser);
	} progressHandler:progressHandler completionHandler:completionHandler]);
}

- (nullable NSProgress *)prepopulateDatabaseWithInputStream:(NSInputStream *)davInputStream basePath:(NSString *)basePath progressHandler:(nullable void(^)(NSUInteger folderCount, NSUInteger fileCount))progressHandler completionHandler:(void (^)(NSError *_Nullable error))completionHandler
{
	return ([self _prepopulateDatabaseWithXMLParserProvider:^OCXMLParser * _Nullable {
		OCXMLParser *parser = nil;
		NSMutableDictionary<NSString *,OCUser *> *usersByUserID = [NSMutableDictionary new];

		if ((parser = [[OCXMLParser alloc] initWithParser:[[NSXMLParser alloc] initWithStream:davInputStream]]) != nil)
		{
			parser.options = [NSMutableDictionary dictionaryWithObjectsAndKeys:
				basePath, 	@"basePath",
				usersByUserID, 	@"usersByUserID",
			nil];
		}

		return (parser);
	} progressHandler:progressHandler completionHandler:completionHandler]);
}

- (nullable NSProgress *)_prepopulateDatabaseWithXMLParserProvider:(OCXMLParser * __nullable(^)(void))xmlParserProvider progressHandler:(nullable void(^)(NSUInteger folderCount, NSUInteger fileCount))progressHandler completionHandler:(void (^)(NSError *_Nullable error))completionHandler
{
	NSProgress *parseProgress = [NSProgress indeterminateProgress];
	OCDatabase *db = self.database;
	__block BOOL parseCancelled = NO;

	parseProgress.cancellationHandler = ^{
		parseCancelled = YES;
	};

	[self.database.sqlDB queueBlock:^{
		OCXMLParser *parser;
		NSMutableArray<OCItem *> *queuedItems = [NSMutableArray new];
		__block NSUInteger itemCount = 0, folderCount = 0, errorCount = 0;
		__block NSError *completionError = nil;
		NSUInteger commitSize = 200;

		void (^StoreItem)(OCItem *item, BOOL flush) = ^(OCItem *item, BOOL flush) {
			if (item != nil)
			{
				[queuedItems addObject:item];
			}

			if ((queuedItems.count >= commitSize) || flush)
			{
				[db addCacheItems:queuedItems syncAnchor:@(0) completionHandler:^(OCDatabase *db, NSError *error) {
					if (error != nil)
					{
						completionError = error;
					}

					[queuedItems removeAllObjects];
				}];
			}
		};

		OCLogDebug(@"Database path: %@", db.databaseURL.path);

		if ((parser = xmlParserProvider()) != nil)
		{
			NSMutableDictionary<OCPath, OCItem *> *openItemByPath = [NSMutableDictionary new];
			NSMutableArray<OCPath> *openPaths = [NSMutableArray new];

			parser.parsedObjectStreamConsumer = ^(OCXMLParser *parser, NSError *error, id parsedObject) {
				if (completionError == nil)
				{
					if (error != nil)
					{
						completionError = error;
					}
					else if (parseCancelled)
					{
						completionError = OCError(OCErrorCancelled);
					}
				}

				if (completionError != nil)
				{
					errorCount++;

					[parser abort];
					return;
				}

				if (parsedObject != nil)
				{
					OCItem *item = parsedObject;
					OCPath itemPath = item.path;
					OCPath parentPath = itemPath.parentPath;

					if (parentPath.length > 0)
					{
						OCItem *parentItem;

						// Add parent File and Local IDs to the item
						if ((parentItem = openItemByPath[parentPath]) != nil)
						{
							item.parentFileID = parentItem.fileID;
							item.parentLocalID = parentItem.localID;
						}
						else if (![itemPath isEqual:@"/"])
						{
							// Unless it is the root item, count this as an error:
							// the parent folder of every item should always have been received before the items it contains
							OCLogError(@"Unexpectedly missing: parent folder item for %@", item);

							completionError = OCErrorWithInfo(OCErrorInternal, ([NSString stringWithFormat:@"Unexpectedly missing parent item for %@.", item.path]));
							[parser abort];

							return;
						}

						__block NSMutableArray<OCPath> *closedPaths = nil;

						[openPaths enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(OCPath openPath, NSUInteger idx, BOOL * _Nonnull stop) {
							if ([itemPath hasPrefix:openPath])
							{
								// Optimization: if the openPath is a prefix of itemPath, all following openPaths will also be prefixes
								// (otherwise they would already have been closed)
								*stop = YES;
							}
							else
							{
								// openPath is not a prefix of itemPath, so that folder must already have been fully received and can be removed
								if (closedPaths == nil)
								{
									closedPaths = [NSMutableArray new];
								}

								[closedPaths addObject:openPath];
							}
						}];

						if (closedPaths != nil)
						{
							[openPaths removeObjectsInArray:closedPaths];
							[openItemByPath removeObjectsForKeys:closedPaths];

							// OCLogDebug(@"Closed %ld path(s): %@", closedPaths.count, closedPaths);
						}
					}

					if (item.type == OCItemTypeCollection)
					{
						// Add new folder
						// (important that this happens after removing all folders that are not parent folders, from the open paths list)
						[openPaths addObject:itemPath];
						openItemByPath[itemPath] = item;

						folderCount++;
					}

					itemCount++;
					// OCLogDebug(@"Path: %@ (%ld)", item.path, (long)item.type);

					if (((itemCount % 1000) == 0) && (progressHandler != nil))
					{
						progressHandler(folderCount, itemCount-folderCount);
					}

					StoreItem(item, NO);
				}
			};

			[parser addObjectCreationClasses:@[ [OCItem class], [NSError class] ]];

			if ([parser parse])
			{
				OCLogDebug(@"Success!");
			}

			// Flush the rest of the items to the database
			StoreItem(nil, YES);

			// Add open paths as directory update jobs
			if (openPaths.count == 1)
			{
				// Remove root path if open path only contains the root path
				[openPaths removeObject:@"/"];
			}

			for (OCPath openPath in openPaths)
			{
				[db addDirectoryUpdateJob:[OCCoreDirectoryUpdateJob withPath:openPath] completionHandler:^(OCDatabase *db, NSError *error, OCCoreDirectoryUpdateJob *updateJob) {
					if (error != nil)
					{
						completionError = error;
					}
				}];
			}

			OCLogDebug(@"Error: %@, Items: %lu (folders: %lu, files: %lu), Open Paths: %@", completionError, itemCount, folderCount, (itemCount-folderCount), openPaths);
		}

		completionHandler(completionError);
	}];

	return (parseProgress);
}

- (nullable NSProgress *)streamMetadataWithCompletionHandler:(void(^)(NSError *_Nullable error, NSInputStream *_Nullable inputStream, NSString *_Nullable basePath))completionHandler
{
	OCConnection *connection;
	NSProgress *propFindProgress = [NSProgress indeterminateProgress];
	__block BOOL propFindCancelled = NO;
	__block BOOL completionHandlerCalled = NO;
	void(^resultHandler)(NSError *_Nullable error, NSInputStream *_Nullable inputStream, NSString *_Nullable basePath) = ^(NSError *_Nullable error, NSInputStream *_Nullable inputStream, NSString *_Nullable basePath) {
		if (!completionHandlerCalled)
		{
			completionHandlerCalled = YES;
			completionHandler(error,inputStream, basePath);
		}
	};

	propFindProgress.cancellationHandler = ^{
		propFindCancelled = YES;
	};

	if ((connection = [[OCConnection alloc] initWithBookmark:self.bookmark]) != nil)
	{
		[connection connectWithCompletionHandler:^(NSError * _Nullable error, OCIssue * _Nullable issue) {
			if (error != nil)
			{
				resultHandler(error, nil, nil);
				return;
			}
			else if (issue != nil)
			{
				resultHandler(issue.error, nil, nil);
				return;
			}

			if (propFindCancelled)
			{
				[connection disconnectWithCompletionHandler:^{
					resultHandler(OCError(OCErrorCancelled), nil, nil);
				}];
			}

			NSProgress *retrieveItemsProgress;
			OCHTTPRequestEphermalStreamHandler streamHandler;
			__block BOOL initialStreamHandlerCallback = YES;

			streamHandler = ^(OCHTTPRequest *request, OCHTTPResponse * _Nullable response, NSInputStream * _Nullable inputStream, NSError * _Nullable error) {
				if (initialStreamHandlerCallback)
				{
					initialStreamHandlerCallback = NO;

					resultHandler(error, inputStream, [((NSURL *)request.userInfo[@"endpointURL"]) path]);
				}
			};

			retrieveItemsProgress = [connection retrieveItemListAtPath:@"/" depth:OCPropfindDepthInfinity options:@{
				OCConnectionOptionResponseStreamHandler : [streamHandler copy]
			} resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
				[connection disconnectWithCompletionHandler:^{
					if (propFindCancelled)
					{
						resultHandler(OCError(OCErrorCancelled), nil, nil);
					}
					else
					{
						resultHandler(event.error, nil, nil);
					}
				}];
			} userInfo:nil ephermalUserInfo:nil]];

			propFindProgress.cancellationHandler = ^{
				[retrieveItemsProgress cancel];
				propFindCancelled = YES;
			};
		}];
	}

	return (propFindProgress);
}

- (nullable NSProgress *)retrieveMetadataWithCompletionHandler:(void(^)(NSError *_Nullable error, OCDAVRawResponse *_Nullable davRawResponse))completionHandler
{
	OCConnection *connection;
	NSProgress *propFindProgress = [NSProgress indeterminateProgress];
	__block BOOL propFindCancelled = NO;

	propFindProgress.cancellationHandler = ^{
		propFindCancelled = YES;
	};

	if ((connection = [[OCConnection alloc] initWithBookmark:self.bookmark]) != nil)
	{
		[connection connectWithCompletionHandler:^(NSError * _Nullable error, OCIssue * _Nullable issue) {
			if (error != nil)
			{
				completionHandler(error, nil);
				return;
			}
			else if (issue != nil)
			{
				completionHandler(issue.error, nil);
				return;
			}

			if (propFindCancelled)
			{
				[connection disconnectWithCompletionHandler:^{
					completionHandler(OCError(OCErrorCancelled), nil);
				}];
			}

			NSError *folderCreationError;

			if (![NSFileManager.defaultManager createDirectoryAtURL:self.davRawResponseFolderURL withIntermediateDirectories:YES attributes:nil error:&folderCreationError])
			{
				[connection disconnectWithCompletionHandler:^{
					completionHandler(folderCreationError, nil);
				}];
			}
			else
			{
				NSURL *responseFileURL = [self.davRawResponseFolderURL URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:NO];
				NSProgress *retrieveItemsProgress;

				retrieveItemsProgress = [connection retrieveItemListAtPath:@"/" depth:OCPropfindDepthInfinity options:@{
					OCConnectionOptionResponseDestinationURL : responseFileURL
				} resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
					[connection disconnectWithCompletionHandler:^{
						if (propFindCancelled)
						{
							completionHandler(OCError(OCErrorCancelled), nil);
						}
						else
						{
							completionHandler(event.error, event.result);
						}
					}];
				} userInfo:nil ephermalUserInfo:nil]];

				propFindProgress.cancellationHandler = ^{
					[retrieveItemsProgress cancel];
					propFindCancelled = YES;
				};
			}
		}];
	}

	return (propFindProgress);
}

@end
