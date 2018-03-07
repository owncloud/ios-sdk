//
//  OCBookmark.h
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
#import "OCAuthenticationMethod.h"

typedef NSUUID* OCBookmarkUUID;

@interface OCBookmark : NSObject <NSSecureCoding>

@property(readonly) OCBookmarkUUID uuid; //!< UUID uniquely identifying the bookmark

@property(strong) NSString *name; //!< Name of the server
@property(strong) NSURL *url; //!< URL to use to connect to the server

@property(strong) NSURL *originURL; //!< URL originally provided by the user, which then redirected to .url. In case .url becomes invalid, the originURL can be used to find the new server. If originURL is set, UI should present it prominently - while also displaying .url near it.

@property(strong) NSData *certificateData; //!< Certificate last used by the server this bookmark refers to
@property(strong) NSDate *certificateModificationDate; //!< Date the certificate stored in this bookmark was last modified.

@property(strong) OCAuthenticationMethodIdentifier authenticationMethodIdentifier; //!< Identifies the authentication method to use
@property(strong,nonatomic) NSData *authenticationData; //!< OCAuthenticationMethod's data (opaque) needed to log into the server. Backed by keychain.

@property(assign) BOOL requirePIN; //!< YES if the user needs to enter a PIN before using this bookmark.
@property(strong,nonatomic) NSString *pin; //!< The PIN the user needs to enter. Backed by keychain.

+ (instancetype)bookmarkForURL:(NSURL *)url; //!< Creates a bookmark for the ownCloud server with the specified URL.

+ (instancetype)bookmarkFromBookmarkData:(NSData *)bookmarkData; //!< Creates a bookmark from BookmarkData

- (NSData *)bookmarkData; //!< Returns the BookmarkData for the bookmark, suitable for saving to disk.

@end

extern NSNotificationName OCBookmarkAuthenticationDataChangedNotification; //!< Name of notification that is sent whenever a bookmark#s authenticationData is changed. The object of the notification is the bookmark.
