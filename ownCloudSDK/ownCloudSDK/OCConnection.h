//
//  OCConnection.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCBookmark.h"
#import "OCAuthenticationMethod.h"
#import "OCTypes.h"
#import "OCEventTarget.h"
#import "OCShare.h"

@class OCBookmark;
@class OCAuthenticationMethod;
@class OCItem;
@class OCActivity;
@class OCConnectionQueue;

@interface OCConnection : NSObject

@property(strong) OCBookmark *bookmark;
@property(strong) OCAuthenticationMethod *authenticationMethod;

@property(strong) OCConnectionQueue *commandQueue; //!< Queue for requests that carry metadata commands (move, delete, retrieve list, ..)

@property(strong) OCConnectionQueue *uploadQueue; //!< Queue for requests that upload files / changes
@property(strong) OCConnectionQueue *downloadQueue; //!< Queue for requests that download files / changes

- (instancetype)initWithBookmark:(OCBookmark *)bookmark;

#pragma mark - Authentication
- (void)requestSupportedAuthenticationMethodsWithCompletionHandler:(void(^)(NSError *error, NSArray <OCAuthenticationMethodIdentifier> *))completionHandler; //!< Requests a list of supported authentication methods and returns the result

- (void)generateAuthenticationDataWithMethod:(OCAuthenticationMethodIdentifier)methodIdentifier options:(OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(void(^)(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData))completionHandler; //!< Uses the OCAuthenticationMethod to generate the authenticationData for storing in the bookmark. It is not directly stored in the bookmark so that an app can decide on its own when to overwrite existing data - or save the result.

#pragma mark - Metadata actions
- (OCActivity *)retrieveItemListAtPath:(OCPath)path completionHandler:(void(^)(NSError *error, NSArray <OCItem *> *items))completionHandler; //!< Retrieves the items at the specified path

#pragma mark - Actions
- (OCActivity *)createFolderNamed:(NSString *)newFolderName atPath:(OCPath)path options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget;
- (OCActivity *)createEmptyFileNamed:(NSString *)newFileName atPath:(OCPath)path options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget;

- (OCActivity *)moveItem:(OCItem *)item to:(OCPath)newParentDirectoryPath resultTarget:(OCEventTarget *)eventTarget;
- (OCActivity *)copyItem:(OCItem *)item to:(OCPath)newParentDirectoryPath options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget;

- (OCActivity *)deleteItem:(OCItem *)item resultTarget:(OCEventTarget *)eventTarget;

- (OCActivity *)uploadFileAtURL:(NSURL *)url to:(OCPath)newParentDirectoryPath resultTarget:(OCEventTarget *)eventTarget;
- (OCActivity *)downloadItem:(OCItem *)item to:(OCPath)newParentDirectoryPath resultTarget:(OCEventTarget *)eventTarget;

- (OCActivity *)retrieveThumbnailFor:(OCItem *)item resultTarget:(OCEventTarget *)eventTarget;

- (OCActivity *)shareItem:(OCItem *)item options:(OCShareOptions)options resultTarget:(OCEventTarget *)eventTarget;

@end
