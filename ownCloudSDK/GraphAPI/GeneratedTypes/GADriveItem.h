//
// GADriveItem.h
// Autogenerated / Managed by ocapigen
// Copyright (C) 2025 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2025, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

// occgen: includes { "locked" : true }
#import <Foundation/Foundation.h>
#import "GAGraphObject.h"
#import "OCDrive.h"

// occgen: forward declarations { "locked" : true }
@class GAAudio;
@class GADeleted;
@class GADriveItem;
@class GAFileSystemInfo;
@class GAFolder;
@class GAGeoCoordinates;
@class GAIdentitySet;
@class GAImage;
@class GAItemReference;
@class GAOpenGraphFile;
@class GAPermission;
@class GAPhoto;
@class GARemoteItem;
@class GARoot;
@class GASpecialFolder;
@class GAThumbnailSet;
@class GATrash;
@class GAVideo;

// occgen: type start
NS_ASSUME_NONNULL_BEGIN
@interface GADriveItem : NSObject <GAGraphObject, NSSecureCoding>

// occgen: type properties { "customPropertyTypes" : { "eTag" : "OCFileETag", "identifier" : "OCFileID" }}
@property(strong, nullable) OCFileID identifier; //!< Read-only.
@property(strong, nullable) GAIdentitySet *createdBy; //!< Identity of the user, device, or application which created the item. Read-only.
@property(strong, nullable) NSDate *createdDateTime; //!< [string:date-time] Date and time of item creation. Read-only. | pattern: ^[0-9]{4,}-(0[1-9]|1[012])-(0[1-9]|[12][0-9]|3[01])[Tt]([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]([.][0-9]{1,12})?([Zz]|[+-][0-9][0-9]:[0-9][0-9])$
@property(strong, nullable) NSString *desc; //!< Provides a user-visible description of the item. Optional.
@property(strong, nullable) OCFileETag eTag; //!< ETag for the item. Read-only.
@property(strong, nullable) GAIdentitySet *lastModifiedBy; //!< Identity of the user, device, and application which last modified the item. Read-only.
@property(strong, nullable) NSDate *lastModifiedDateTime; //!< [string:date-time] Date and time the item was last modified. Read-only. | pattern: ^[0-9]{4,}-(0[1-9]|1[012])-(0[1-9]|[12][0-9]|3[01])[Tt]([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]([.][0-9]{1,12})?([Zz]|[+-][0-9][0-9]:[0-9][0-9])$
@property(strong, nullable) NSString *name; //!< The name of the item. Read-write.
@property(strong, nullable) GAItemReference *parentReference; //!< Parent information, if the item has a parent. Read-write.
@property(strong, nullable) NSURL *webUrl; //!< URL that displays the resource in the browser. Read-only.
@property(strong, nullable) NSString *content; //!< [string:base64url] The content stream, if the item represents a file.
@property(strong, nullable) NSString *cTag; //!< An eTag for the content of the item. This eTag is not changed if only the metadata is changed. Note This property is not returned if the item is a folder. Read-only.
@property(strong, nullable) GADeleted *deleted;
@property(strong, nullable) GAOpenGraphFile *file;
@property(strong, nullable) GAFileSystemInfo *fileSystemInfo;
@property(strong, nullable) GAFolder *folder;
@property(strong, nullable) GAImage *image;
@property(strong, nullable) GAPhoto *photo; //!< Photo metadata, if the item is a photo. Read-only.
@property(strong, nullable) GAGeoCoordinates *location; //!< Location metadata, if the item has location data. Read-only.
@property(strong, nullable) NSArray<GAThumbnailSet *> *thumbnails; //!< Collection containing ThumbnailSet objects associated with the item. Read-only. Nullable.
@property(strong, nullable) GARoot *root;
@property(strong, nullable) GATrash *trash;
@property(strong, nullable) GASpecialFolder *specialFolder;
@property(strong, nullable) GARemoteItem *remoteItem;
@property(strong, nullable) NSNumber *size; //!< [integer:int64] Size of the item in bytes. Read-only.
@property(strong, nullable) NSURL *webDavUrl; //!< WebDAV compatible URL for the item. Read-only.
@property(strong, nullable) NSArray<GADriveItem *> *children; //!< Collection containing Item objects for the immediate children of Item. Only items representing folders have children. Read-only. Nullable.
@property(strong, nullable) NSArray<GAPermission *> *permissions; //!< The set of permissions for the item. Read-only. Nullable.
@property(strong, nullable) GAAudio *audio; //!< Audio metadata, if the item is an audio file. Read-only.
@property(strong, nullable) GAVideo *video; //!< Video metadata, if the item is a video. Read-only.
@property(strong, nullable) NSNumber *clientSynchronize; //!< [boolean] Indicates if the item is synchronized with the underlying storage provider. Read-only.
@property(strong, nullable) NSNumber *UIHidden; //!< [boolean] Properties or facets (see UI.Facet) annotated with this term will not be rendered if the annotation evaluates to true. Users can set this to hide permissions.

// occgen: type protected {"locked":true}


// occgen: type end
@end
NS_ASSUME_NONNULL_END

