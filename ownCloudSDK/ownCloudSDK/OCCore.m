//
//  OCCore.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCCore.h"

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
	}
	
	return(self);
}

- (void)dealloc
{
}

#pragma mark - Query
- (void)startQuery:(OCQuery *)query
{
	// Stub implementation
}

- (void)stopQuery:(OCQuery *)query
{
	// Stub implementation
}

#pragma mark - Commands
- (OCActivity *)createFolderNamed:(NSString *)newFolderName atPath:(OCPath)path options:(NSDictionary *)options resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (OCActivity *)createEmptyFileNamed:(NSString *)newFileName atPath:(OCPath)path options:(NSDictionary *)options resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (OCActivity *)renameItem:(OCItem *)item to:(NSString *)newFileName resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (OCActivity *)moveItem:(OCItem *)item to:(OCPath)newParentDirectoryPath resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (OCActivity *)copyItem:(OCItem *)item to:(OCPath)newParentDirectoryPath options:(NSDictionary *)options resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (OCActivity *)deleteItem:(OCItem *)item resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (OCActivity *)uploadFileAtURL:(NSURL *)url to:(OCPath)newParentDirectoryPath resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (OCActivity *)downloadItem:(OCItem *)item to:(OCPath)newParentDirectoryPath resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (OCActivity *)retrieveThumbnailFor:(OCItem *)item resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (OCActivity *)shareItem:(OCItem *)item options:(OCShareOptions)options resultHandler:(OCCoreActionShareHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (OCActivity *)requestAvailableOfflineCapabilityForItem:(OCItem *)item completionHandler:(OCCoreCompletionHandler)completionHandler
{
	return(nil); // Stub implementation
}

- (OCActivity *)terminateAvailableOfflineCapabilityForItem:(OCItem *)item completionHandler:(OCCoreCompletionHandler)completionHandler
{
	return(nil); // Stub implementation
}

- (OCActivity *)synchronizeWithServer
{
	return(nil); // Stub implementation
}

#pragma mark - OCEventHandler methods
- (void)handleEvent:(OCEvent *)event sender:(id)sender;
{
	// Stub implementation
}

@end
