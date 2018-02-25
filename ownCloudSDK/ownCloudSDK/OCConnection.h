//
//  OCConnection.h
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

#import <Foundation/Foundation.h>
#import "OCBookmark.h"
#import "OCAuthenticationMethod.h"
#import "OCTypes.h"
#import "OCEventTarget.h"
#import "OCShare.h"
#import "OCClassSettings.h"

@class OCBookmark;
@class OCAuthenticationMethod;
@class OCItem;
@class OCConnectionQueue;
@class OCConnectionRequest;

typedef void(^OCConnectionEphermalResultHandler)(OCConnectionRequest *request, NSError *error);

typedef OCClassSettingsKey OCConnectionEndpointID NS_TYPED_ENUM;

@interface OCConnection : NSObject <OCClassSettingsSupport>
{
	OCBookmark *_bookmark;
	OCAuthenticationMethod *_authenticationMethod;

	OCConnectionQueue *_commandQueue;

	OCConnectionQueue *_uploadQueue;
	OCConnectionQueue *_downloadQueue;
}

@property(strong) OCBookmark *bookmark;
@property(strong,nonatomic) OCAuthenticationMethod *authenticationMethod;

@property(strong) OCConnectionQueue *commandQueue; //!< Queue for requests that carry metadata commands (move, delete, retrieve list, ..)

@property(strong) OCConnectionQueue *uploadQueue; //!< Queue for requests that upload files / changes
@property(strong) OCConnectionQueue *downloadQueue; //!< Queue for requests that download files / changes

#pragma mark - Init
- (instancetype)init NS_UNAVAILABLE; //!< Always returns nil. Please use the designated initializer instead.
- (instancetype)initWithBookmark:(OCBookmark *)bookmark;

#pragma mark - Endpoints
- (NSString *)pathForEndpoint:(OCConnectionEndpointID)endpoint; //!< Returns the path of an endpoint identified by its OCConnectionEndpointID
- (NSURL *)URLForEndpoint:(OCConnectionEndpointID)endpoint options:(NSDictionary <NSString *,id> *)options; //!< Returns the URL of an endpoint identified by its OCConnectionEndpointID, allowing additional options (reserved for future use)

#pragma mark - Authentication
- (void)requestSupportedAuthenticationMethodsWithCompletionHandler:(void(^)(NSError *error, NSArray <OCAuthenticationMethodIdentifier> *))completionHandler; //!< Requests a list of supported authentication methods and returns the result

- (void)generateAuthenticationDataWithMethod:(OCAuthenticationMethodIdentifier)methodIdentifier options:(OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(void(^)(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData))completionHandler; //!< Uses the OCAuthenticationMethod to generate the authenticationData for storing in the bookmark. It is not directly stored in the bookmark so that an app can decide on its own when to overwrite existing data - or save the result.

#pragma mark - Metadata actions
- (NSProgress *)retrieveItemListAtPath:(OCPath)path completionHandler:(void(^)(NSError *error, NSArray <OCItem *> *items))completionHandler; //!< Retrieves the items at the specified path

#pragma mark - Actions
- (NSProgress *)createFolderNamed:(NSString *)newFolderName atPath:(OCPath)path options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget;
- (NSProgress *)createEmptyFileNamed:(NSString *)newFileName atPath:(OCPath)path options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget;

- (NSProgress *)moveItem:(OCItem *)item to:(OCPath)newParentDirectoryPath resultTarget:(OCEventTarget *)eventTarget;
- (NSProgress *)copyItem:(OCItem *)item to:(OCPath)newParentDirectoryPath options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget;

- (NSProgress *)deleteItem:(OCItem *)item resultTarget:(OCEventTarget *)eventTarget;

- (NSProgress *)uploadFileAtURL:(NSURL *)url to:(OCPath)newParentDirectoryPath resultTarget:(OCEventTarget *)eventTarget;
- (NSProgress *)downloadItem:(OCItem *)item to:(OCPath)newParentDirectoryPath resultTarget:(OCEventTarget *)eventTarget;

- (NSProgress *)retrieveThumbnailFor:(OCItem *)item resultTarget:(OCEventTarget *)eventTarget;

- (NSProgress *)shareItem:(OCItem *)item options:(OCShareOptions)options resultTarget:(OCEventTarget *)eventTarget;

- (NSProgress *)sendRequest:(OCConnectionRequest *)request toQueue:(OCConnectionQueue *)queue ephermalCompletionHandler:(OCConnectionEphermalResultHandler)ephermalResultHandler;

@end

extern OCConnectionEndpointID OCConnectionEndpointIDCapabilities;
extern OCConnectionEndpointID OCConnectionEndpointIDWebDAV;

extern OCClassSettingsKey OCConnectionInsertXRequestTracingID;

#import "OCConnectionRequest.h"
