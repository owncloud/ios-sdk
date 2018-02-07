//
//  OCBookmark.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCAuthenticationMethod.h"

@interface OCBookmark : NSObject <NSSecureCoding>

@property(readonly) NSUUID *uuid; //!< UUID uniquely identifying the bookmark

@property(strong) NSString *name; //!< Name of the server
@property(strong) NSURL *url; //!< URL of the server

@property(strong) OCAuthenticationMethodIdentifier authenticationMethodIdentifier; //!< Identifies the authentication method to use
@property(strong,nonatomic) NSData *authenticationData; //!< OCAuthenticationMethod's data (opaque) needed to log into the server. Backed by keychain.

@property(assign) BOOL requirePIN; //!< YES if the user needs to enter a PIN before using this bookmark.
@property(strong,nonatomic) NSString *pin; //!< The PIN the user needs to enter. Backed by keychain.

+ (instancetype)bookmarkForURL:(NSURL *)url; //!< Creates a bookmark for the ownCloud server with the specified URL.

+ (instancetype)bookmarkFromBookmarkData:(NSData *)bookmarkData; //!< Creates a bookmark from BookmarkData

- (NSData *)bookmarkData; //!< Returns the BookmarkData for the bookmark, suitable for saving to disk.

@end
