//
//  OCCore.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.02.18.
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
#import "OCQuery+OCCore.h"
#import "OCCoreTask.h"

@implementation OCCore

@synthesize bookmark = _bookmark;

@synthesize vault = _vault;
@synthesize connection = _connection;

@synthesize delegate = _delegate;

#pragma mark - Init
- (instancetype)init
{
	// Enforce use of designated initializer
	return (nil);
}

- (instancetype)initWithBookmark:(OCBookmark *)bookmark
{
	if ((self = [super init]) != nil)
	{
		_bookmark = bookmark;

		_vault = [[OCVault alloc] initWithBookmark:bookmark];

		_connection = [[OCConnection alloc] initWithBookmark:bookmark];

		_queries = [NSMutableArray new];

		_queue = dispatch_queue_create("OCCore work queue", DISPATCH_QUEUE_SERIAL);
	}
	
	return(self);
}

- (void)dealloc
{
}

#pragma mark - Query
- (void)startQuery:(OCQuery *)query
{
	if (query != nil) { return; }

	[self queueBlock:^{
		// Add query to list of queries
		[_queries addObject:query];

		// Update query state to "started"
		query.state = OCQueryStateStarted;

		// Start task
		[self startItemListTaskForPath:query.queryPath];
	}];
}

- (void)stopQuery:(OCQuery *)query
{
	if (query != nil) { return; }

	[_queries removeObject:query];
}

#pragma mark - Tasks
- (void)startItemListTaskForPath:(OCPath)path
{
	OCCoreTask *task;

	if ((task = [[OCCoreTask alloc] initWithPath:path]) != nil)
	{
		// Query cache
		task.cachedSet.state = OCCoreTaskSetStateStarted;

		[self retrieveCachedItemListAtPath:path completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
			[task.cachedSet updateWithError:error items:items];

			[self handleUpdatedTask:task retrievedSet:NO];
		}];

		// Query server
		task.retrievedSet.state = OCCoreTaskSetStateStarted;

		[self retrieveServerItemListAtPath:path completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
			[task.retrievedSet updateWithError:error items:items];

			[self handleUpdatedTask:task retrievedSet:YES];
		}];
	}
}

- (void)handleUpdatedTask:(OCCoreTask *)task retrievedSet:(BOOL)retrievedSet
{
	for (OCQuery *query in _queries)
	{
		if ([query.queryPath isEqual:task.path])
		{

		}
	}
}

#pragma mark - Internal Meta Data Requests
- (NSProgress *)retrieveCachedItemListAtPath:(OCPath)path completionHandler:(void(^)(NSError *error, NSArray <OCItem *> *items))completionHandler
{
	// To be implemented

	[self queueBlock:^{
		completionHandler(nil, nil);
	}];

	return (nil);
}

- (NSProgress *)retrieveServerItemListAtPath:(OCPath)path completionHandler:(void(^)(NSError *error, NSArray <OCItem *> *items))completionHandler
{
	return ([_connection retrieveItemListAtPath:path completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
		[self queueBlock:^{
			if (error == nil)
			{
				[self processReceivedItems:items atPath:path];
			}

			if (completionHandler != nil)
			{
				completionHandler(error,items);
			}
		}];
	}]);
}

- (void)processReceivedItems:(NSArray <OCItem *> *)items atPath:(OCPath)path
{
}

#pragma mark - Commands
- (NSProgress *)createFolderNamed:(NSString *)newFolderName atPath:(OCPath)path options:(NSDictionary *)options resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (NSProgress *)createEmptyFileNamed:(NSString *)newFileName atPath:(OCPath)path options:(NSDictionary *)options resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (NSProgress *)renameItem:(OCItem *)item to:(NSString *)newFileName resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (NSProgress *)moveItem:(OCItem *)item to:(OCPath)newParentDirectoryPath resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (NSProgress *)copyItem:(OCItem *)item to:(OCPath)newParentDirectoryPath options:(NSDictionary *)options resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (NSProgress *)deleteItem:(OCItem *)item resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (NSProgress *)uploadFileAtURL:(NSURL *)url to:(OCPath)newParentDirectoryPath resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (NSProgress *)downloadItem:(OCItem *)item to:(OCPath)newParentDirectoryPath resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (NSProgress *)retrieveThumbnailFor:(OCItem *)item resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (NSProgress *)shareItem:(OCItem *)item options:(OCShareOptions)options resultHandler:(OCCoreActionShareHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (NSProgress *)requestAvailableOfflineCapabilityForItem:(OCItem *)item completionHandler:(OCCoreCompletionHandler)completionHandler
{
	return(nil); // Stub implementation
}

- (NSProgress *)terminateAvailableOfflineCapabilityForItem:(OCItem *)item completionHandler:(OCCoreCompletionHandler)completionHandler
{
	return(nil); // Stub implementation
}

- (NSProgress *)synchronizeWithServer
{
	return(nil); // Stub implementation
}

#pragma mark - OCEventHandler methods
- (void)handleEvent:(OCEvent *)event sender:(id)sender;
{
	// Stub implementation
}

#pragma mark - Queue
- (void)queueBlock:(dispatch_block_t)block
{
	if (block != nil)
	{
		dispatch_async(_queue, block);
	}
}

@end
