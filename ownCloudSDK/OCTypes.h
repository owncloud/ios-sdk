//
//  OCTypes.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.02.18.
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

#ifndef OCTypes_h
#define OCTypes_h

typedef NSString* OCPath; //!< NSString representing the path relative to the server's root directory.

typedef NSString* OCLocalID; //!< Unique local identifier of the item (persists over lifetime of file, incl. across modifications and placeholder -> item transition).

typedef NSString* OCFileID; //!< Unique identifier of the item on the server (persists over lifetime of file, incl. across modifications) (files and folders)
typedef NSString* OCFileETag; //!< Identifier unique to a specific combination of contents and metadata. Can be used to detect changes. (files and folders)

typedef NSString* OCLocalAttribute NS_TYPED_ENUM; //!< Identifier uniquely identifying a local attribute

typedef NSNumber* OCItemFavorite; //!< Favorite status of an item (boolean)
typedef NSString* OCItemPropertyName NS_TYPED_ENUM; //!< Name of an item property

typedef NSString* OCItemDownloadTriggerID NS_TYPED_ENUM; //!< Identifier of what triggered the download of an item

typedef id OCDatabaseID; //!< Object referencing the item in the database (OCDatabase-specific, OCItem's NSSecureCoding support assumes NSValue or NSValue subclass).
typedef NSNumber* OCDatabaseTimestamp; //!< ((NSUInteger)NSDate.timeIntervalSinceReferenceDate) value an entry was added to or last updated in the database.

typedef NSNumber* OCSyncAnchor; //!< Sync Anchor (running number, increasing in value with every change made)
typedef NSUUID* OCCoreRunIdentifier;

typedef void(^OCCompletionHandler)(id sender, NSError *error);

typedef void(^OCConnectionAuthenticationAvailabilityHandler)(NSError *error, BOOL authenticationIsAvailable);

typedef NSString* OCSyncActionIdentifier NS_TYPED_ENUM;
typedef NSString* OCSyncActionParameter NS_TYPED_ENUM;
typedef NSString* OCSyncActionCategory NS_TYPED_ENUM;
typedef NSNumber* OCSyncRecordID;
typedef NSNumber* OCSyncRecordRevision;

typedef NSNumber* OCSyncLaneID;
typedef NSString* OCSyncLaneTag;

// typedef NSString* OCJobID; //!< Identifier uniquely identifying a job. Typically used as persistent ID across requests to track a job's connectivity status.

#endif /* OCTypes_h */
