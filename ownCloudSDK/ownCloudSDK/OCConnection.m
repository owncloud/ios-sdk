//
//  OCConnection.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCConnection.h"

@implementation OCConnection

@synthesize bookmark = _bookmark;
@synthesize authenticationMethod = _authenticationMethod;

@synthesize commandQueue = _commandQueue;

@synthesize uploadQueue = _uploadQueue;
@synthesize downloadQueue = _downloadQueue;

#pragma mark - Init
- (instancetype)init
{
	return(nil);
}

- (instancetype)initWithBookmark:(OCBookmark *)bookmark
{
	self.bookmark = bookmark;
	
	return (self);
}

#pragma mark - Authentication
- (void)requestSupportedAuthenticationMethodsWithCompletionHandler:(void(^)(NSError *error, NSArray <OCAuthenticationMethodIdentifier> *))completionHandler
{
	// Stub implementation
}

- (void)generateAuthenticationDataWithMethod:(OCAuthenticationMethodIdentifier)methodIdentifier options:(OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(void(^)(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData))completionHandler
{
	// Stub implementation
}

#pragma mark - Metadata actions
- (OCActivity *)retrieveItemListAtPath:(OCPath)path completionHandler:(void(^)(NSError *error, NSArray <OCItem *> *items))completionHandler
{
	// Stub implementation
	return(nil);
}

#pragma mark - Actions
- (OCActivity *)createFolderNamed:(NSString *)newFolderName atPath:(OCPath)path options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget
{
	// Stub implementation
	return(nil);
}

- (OCActivity *)createEmptyFileNamed:(NSString *)newFileName atPath:(OCPath)path options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget
{
	// Stub implementation
	return(nil);
}

- (OCActivity *)moveItem:(OCItem *)item to:(OCPath)newParentDirectoryPath resultTarget:(OCEventTarget *)eventTarget
{
	// Stub implementation
	return(nil);
}

- (OCActivity *)copyItem:(OCItem *)item to:(OCPath)newParentDirectoryPath options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget
{
	// Stub implementation
	return(nil);
}

- (OCActivity *)deleteItem:(OCItem *)item resultTarget:(OCEventTarget *)eventTarget
{
	// Stub implementation
	return(nil);
}

- (OCActivity *)uploadFileAtURL:(NSURL *)url to:(OCPath)newParentDirectoryPath resultTarget:(OCEventTarget *)eventTarget
{
	// Stub implementation
	return(nil);
}

- (OCActivity *)downloadItem:(OCItem *)item to:(OCPath)newParentDirectoryPath resultTarget:(OCEventTarget *)eventTarget
{
	// Stub implementation
	return(nil);
}


- (OCActivity *)retrieveThumbnailFor:(OCItem *)item resultTarget:(OCEventTarget *)eventTarget
{
	// Stub implementation
	return(nil);
}


- (OCActivity *)shareItem:(OCItem *)item options:(OCShareOptions)options resultTarget:(OCEventTarget *)eventTarget
{
	// Stub implementation
	return(nil);
}

@end
