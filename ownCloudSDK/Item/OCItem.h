//
//  OCItem.h
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
#import "OCTypes.h"
#import "OCShare.h"
#import "OCItemThumbnail.h"
#import "OCItemVersionIdentifier.h"

typedef NS_ENUM(NSInteger, OCItemType)
{
	OCItemTypeFile,		//!< This item is a file.
	OCItemTypeCollection	//!< This item is a collection (usually a directory)
};

typedef NS_ENUM(NSInteger, OCItemStatus)
{
	OCItemStatusAtRest,	//!< This item exists / is at rest
	OCItemStatusTransient	//!< This item is transient (i.e. the item is a placeholder while its actual content is still uploading to the server)
};

typedef NS_OPTIONS(NSInteger, OCItemPermissions)
{							//   Code	Resource	Description
	OCItemPermissionShared		= (1<<0), 	//!< Code "S"	File or Folder	is shared
	OCItemPermissionShareable	= (1<<1), 	//!< Code "R"	File or Folder	can share (includes re-share)
	OCItemPermissionMounted		= (1<<2), 	//!< Code "M" 	File or Folder	is mounted (like on Dropbox, Samba, etc.)
	OCItemPermissionWritable	= (1<<3),	//!< Code "W"	File		can write file
	OCItemPermissionCreateFile	= (1<<4), 	//!< Code "C"	Folder		can create file in folder
	OCItemPermissionCreateFolder	= (1<<5), 	//!< Code "K" 	Folder		can create folder (mkdir)
	OCItemPermissionDelete		= (1<<6), 	//!< Code "D"	File or Folder	can delete file or folder
	OCItemPermissionRename		= (1<<7), 	//!< Code "N"	File or Folder	can rename file or folder
	OCItemPermissionMove		= (1<<8)	//!< Code "V"	File or Folder	can move file or folder
};

typedef NS_ENUM(NSInteger, OCItemThumbnailAvailability)
{
	OCItemThumbnailAvailabilityUnknown,	//!< It's not yet known if a thumbnail is available for this item
	OCItemThumbnailAvailabilityAvailable,	//!< A thumbnail is available for this item
	OCItemThumbnailAvailabilityNone,	//!< No thumbnail is available for this item

	OCItemThumbnailAvailabilityInternal = -1 //!< Internal value. Don't use.
};

@interface OCItem : NSObject <NSSecureCoding>
{
	OCItemVersionIdentifier *_versionIdentifier;

	OCItemThumbnailAvailability _thumbnailAvailability;
}

@property(assign) OCItemType type; //!< The type of the item (e.g. file, collection, ..)

@property(strong) NSString *mimeType; //!< MIME type ("Content Type") of the item

@property(assign) OCItemStatus status; //!< the status of the item (exists/at rest, is transient)
@property(strong) NSProgress *progress; //!< If status is transient, a progress describing the status

@property(assign) OCItemPermissions permissions; //!< ownCloud permissions for the item

@property(strong) NSString *localRelativePath; //!< Path of the local copy of the item, relative to the rootURL of the vault that stores it
@property(assign) BOOL locallyModified; //!< YES if the file at .localURL was created or modified locally. NO if the file at .localURL was downloaded from the server and not modified since.

@property(strong) OCItem *remoteItem; //!< If .locallyModified==YES or .localRelativePath!=nil and a different version is available remotely (on the server), the item as retrieved from the server.

@property(strong) OCPath path; //!< Path of the item on the server relative to root
@property(readonly,nonatomic) NSString *name; //!< Name of the item, derived from .path. (dynamic/ephermal)

@property(strong,nonatomic) OCFileID fileID; //!< Unique identifier of the item on the server (persists over lifetime of file, incl. across modifications) (files only)
@property(strong,nonatomic) OCFileETag eTag; //!< ETag of the item on the server (changes with every modification)
@property(readonly,nonatomic) OCItemVersionIdentifier *versionIdentifier; // (dynamic/ephermal)

@property(assign) NSInteger size; //!< Size in bytes of the item
@property(strong) NSDate *lastModified; //!< Date of last modification

@property(readonly,nonatomic) OCItemThumbnailAvailability thumbnailAvailability; //!< Availability of thumbnails for this item. If OCItemThumbnailAvailabilityUnknown, call -[OCCore retrieveThumbnailFor:resultHandler:] to update it.
@property(strong,nonatomic) OCItemThumbnail *thumbnail; //!< Thumbnail for the item.

@property(strong) NSArray <OCShare *> *shares; //!< Array of existing shares of the item

@property(strong) OCDatabaseID databaseID; //!< OCDatabase-specific ID referencing the item in the database (ephermal!)

#pragma mark - Serialization tools
+ (instancetype)itemFromSerializedData:(NSData *)serializedData;
- (NSData *)serializedData;

@end

