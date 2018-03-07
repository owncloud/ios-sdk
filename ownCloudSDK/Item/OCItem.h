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

typedef NSString* OCFileID; //!< Unique identifier of the item on the server (persists over lifetime of file, incl. across modifications) (files only)

typedef NS_ENUM(NSUInteger, OCItemType)
{
	OCItemTypeFile,		//!< This item is a file.
	OCItemTypeCollection	//!< This item is a collection (usually a directory)
};

typedef NS_ENUM(NSUInteger, OCItemStatus)
{
	OCItemStatusAtRest,	//!< This item exists / is at rest
	OCItemStatusTransient	//!< This item is transient (i.e. the item is a placeholder while its actual content is still uploading to the server)
};

typedef NS_OPTIONS(NSUInteger, OCItemPermissions)
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

@interface OCItem : NSObject <NSSecureCoding>

@property(assign) OCItemType type; //!< The type of the item (e.g. file, collection, ..)

@property(assign) OCItemStatus status; //!< the status of the item (exists/at rest, is transient)
@property(strong) NSProgress *progress; //!< If status is transient, a progress describing the status

@property(assign) OCItemPermissions permissions; //!< ownCloud permissions for the item

@property(strong) NSURL *downloadURL; //!< Download URL for the item on the server
@property(strong) NSURL *localURL; //!< URL for local copy of the item
@property(strong) OCPath path; //!< Path of the item on the server relative to root
@property(readonly) NSString *name; //!< Name of the item, derived from .path.

@property(strong) OCFileID fileID; //!< Unique identifier of the item on the server (persists over lifetime of file, incl. across modifications) (files only)
@property(strong) NSString *eTag; //!< ETag of the item on the server (changes with every modification)

@property(assign) NSUInteger size; //!< Size in bytes of the item
@property(strong) NSDate *lastModified; //!< Date of last modification

@property(strong) NSArray <OCShare *> *shares; //!< Array of existing shares of the item

@end

