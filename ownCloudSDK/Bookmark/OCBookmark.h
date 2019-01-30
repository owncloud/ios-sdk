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
#import "OCCertificate.h"

typedef NSUUID* OCBookmarkUUID;

typedef NS_ENUM(NSUInteger, OCBookmarkAuthenticationDataStorage)
{
	OCBookmarkAuthenticationDataStorageKeychain, 	//!< Store authenticationData in the keychain. Default.
	OCBookmarkAuthenticationDataStorageMemory	//!< Store authenticationData in memory. Should only be used temporarily, for f.ex. editing contexts, where temporarily decoupling the data from the keychain can be desirable.
};

NS_ASSUME_NONNULL_BEGIN

@interface OCBookmark : NSObject <NSSecureCoding, NSCopying>

@property(readonly) OCBookmarkUUID uuid; //!< UUID uniquely identifying the bookmark

@property(strong,nullable) NSString *name; //!< Name of the server
@property(strong,nullable) NSURL *url; //!< URL to use to connect to the server

@property(readonly,nullable) NSString *userName; //!< Convenience method for accessing the userName stored in the authenticationData

@property(strong,nullable) NSURL *originURL; //!< URL originally provided by the user, which then redirected to .url. In case .url becomes invalid, the originURL can be used to find the new server. If originURL is set, UI should present it prominently - while also displaying .url near it.

@property(strong,nullable) OCCertificate *certificate; //!< Certificate last used by the server this bookmark refers to
@property(strong,nullable) NSDate *certificateModificationDate; //!< Date the certificate stored in this bookmark was last modified.

@property(strong,nullable) OCAuthenticationMethodIdentifier authenticationMethodIdentifier; //!< Identifies the authentication method to use
@property(strong,nonatomic,nullable) NSData *authenticationData; //!< OCAuthenticationMethod's data (opaque) needed to log into the server. Backed by keychain or memory depending on .authenticationDataStorage.
@property(assign,nonatomic) OCBookmarkAuthenticationDataStorage authenticationDataStorage; //! Determines where to store authenticationData. Keychain by default. Changing the storage copies the data from the old to the new storage.

@property(strong,nonatomic) NSMutableDictionary<NSString *, id<NSObject,NSSecureCoding>> *userInfo; //!< Dictionary for storing app-specific / custom properties alongside the bookmark

#pragma mark - Creation
+ (instancetype)bookmarkForURL:(NSURL *)url; //!< Creates a bookmark for the ownCloud server with the specified URL.

#pragma mark - Persist / Restore
+ (instancetype)bookmarkFromBookmarkData:(NSData *)bookmarkData; //!< Creates a bookmark from BookmarkData.
- (nullable NSData *)bookmarkData; //!< Returns the BookmarkData for the bookmark, suitable for saving to disk.

#pragma mark - Data replacement
- (void)setValuesFrom:(OCBookmark *)sourceBookmark; //!< Replaces all values in the receiving bookmark with those in the source bookmark.

@end

extern NSNotificationName OCBookmarkAuthenticationDataChangedNotification; //!< Name of notification that is sent whenever a bookmark's authenticationData is changed. The object of the notification is the bookmark. Sent only if .authenticationDataStorage is OCBookmarkAuthenticationDataStorageKeychain.

extern NSNotificationName OCBookmarkUpdatedNotification; //!< Name of notification that can be sent by third parties after completing an update to a bookmark.

NS_ASSUME_NONNULL_END
