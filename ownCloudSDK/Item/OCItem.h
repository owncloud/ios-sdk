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
#import "OCItemThumbnail.h"
#import "OCItemVersionIdentifier.h"

@class OCFile;
@class OCCore;
@class OCShare;
@class OCChecksum;

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

typedef NS_OPTIONS(NSInteger, OCItemSyncActivity)
{
	OCItemSyncActivityNone,
	OCItemSyncActivityDeleting 	= (1<<0),	//!< This item is being deleted, or scheduled to be deleted
	OCItemSyncActivityUploading 	= (1<<1),	//!< This item is being uploaded, or scheduled to be uploaded
	OCItemSyncActivityDownloading 	= (1<<2),	//!< This item is being downloaded, or scheduled to be downloaded
	OCItemSyncActivityCreating	= (1<<3),	//!< This item is being created, or scheduled to be created (both files and folders)
	OCItemSyncActivityUpdating	= (1<<4),	//!< This item is being updated, or scheduled to be updated (both files and folders)
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

typedef NS_ENUM(NSInteger, OCItemCloudStatus)
{
	OCItemCloudStatusCloudOnly, 		//!< Item is only stored remotely (no local copy)
	OCItemCloudStatusLocalCopy,		//!< Item is a local copy of a file on the server
	OCItemCloudStatusLocallyModified,	//!< Item is a modified copy of a file on the server
	OCItemCloudStatusLocalOnly		//!< Item only exists locally. There's no remote copy.
};

#import "OCShare.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCItem : NSObject <NSSecureCoding, NSCopying>
{
	OCItemVersionIdentifier *_versionIdentifier;

	OCItemThumbnailAvailability _thumbnailAvailability;

	NSMutableDictionary<OCLocalAttribute, id> *_localAttributes;
	NSTimeInterval _localAttributesLastModified;

	NSString *_creationHistory;
}

@property(assign) OCItemType type; //!< The type of the item (e.g. file, collection, ..)

@property(nullable,strong) NSString *mimeType; //!< MIME type ("Content Type") of the item

@property(assign) OCItemStatus status; //!< the status of the item (exists/at rest, is transient)

@property(readonly,nonatomic) OCItemCloudStatus cloudStatus; //!< the cloud status of the item (computed using the item's metadata)

@property(assign) BOOL removed; //!< whether the item has been removed (defaults to NO) (stored by database, ephermal otherwise)
@property(nullable,strong) NSProgress *progress; //!< If status is transient, a progress describing the status (ephermal)

@property(assign) OCItemPermissions permissions; //!< ownCloud permissions for the item

@property(nullable,strong) NSString *localRelativePath; //!< Path of the local copy of the item, relative to the filesRootURL of the vault that stores it
@property(assign) BOOL locallyModified; //!< YES if the file at .localRelativePath was created or modified locally. NO if the file at .localRelativePath was downloaded from the server and not modified since.
@property(nullable,strong) OCItemVersionIdentifier *localCopyVersionIdentifier; //!< (Remote) version identifier of the local copy. nil if this version only exists locally.

@property(nullable,strong) OCItem *remoteItem; //!< If .locallyModified==YES or .localRelativePath!=nil and a different version is available remotely (on the server), the item as retrieved from the server.

@property(nullable,strong) OCPath path; //!< Path of the item on the server relative to root
@property(nullable,readonly,nonatomic) NSString *name; //!< Name of the item, derived from .path. (dynamic/ephermal)

@property(nullable,strong) OCPath previousPath; //!< A previous path of the item, f.ex. before being moved (dynamic/ephermal)
@property(nullable,strong) OCFileID previousPlaceholderFileID; //!< FileID of placeholder that was replaced by this item for giving hints to the Sync Engine, so it can inform subsequent sync actions depending on the replaced placeholder (dynamic/ephermal)

@property(nullable,strong) OCLocalID parentLocalID; //!< Unique local identifier of the parent folder (persists over lifetime of item, incl. across modifications and placeholder -> item transitions)
@property(nullable,strong) OCLocalID localID; //!< Unique local identifier of the item (persists over lifetime of item, incl. across modifications and placeholder -> item transitions)

@property(nullable,strong) NSArray<OCChecksum *> *checksums; //!< (Optional) checksums of the item. Typically only requested for uploaded files.

@property(nullable,strong,nonatomic) OCFileID parentFileID; //!< Unique identifier of the parent folder (persists over lifetime of file, incl. across modifications)
@property(nullable,strong,nonatomic) OCFileID fileID; //!< Unique identifier of the item on the server (persists over lifetime of file, incl. across modifications)
@property(nullable,strong,nonatomic) OCFileETag eTag; //!< ETag of the item on the server (changes with every modification)
@property(nullable,readonly,nonatomic) OCItemVersionIdentifier *itemVersionIdentifier; // (dynamic/ephermal)
@property(readonly,nonatomic) BOOL isPlaceholder; //!< YES if this a placeholder item

@property(readonly,nonatomic) BOOL isRoot; //!< YES if this item is representing the root folder

@property(readonly,nonatomic) BOOL hasLocalAttributes; //!< Returns YES if the item has any local attributes
@property(nullable,strong,nonatomic) NSDictionary<OCLocalAttribute, id> *localAttributes; //!< Dictionary of local-only attributes (not synced to server)
@property(assign,nonatomic) NSTimeInterval localAttributesLastModified; //!< Time of last modification of localAttributes

@property(nullable,strong,nonatomic) NSArray <OCSyncRecordID> *activeSyncRecordIDs; //!< Array of IDs of sync records operating on this item
@property(nullable,strong,nonatomic) NSCountedSet <NSNumber *> *syncActivityCounts; //!< Counts of OCItemSyncActivity. Starts only when a OCItemSyncActivity has already been set in syncActivity
@property(assign) OCItemSyncActivity syncActivity; //!< mask of running sync activity for the item

@property(assign) NSInteger size; //!< Size in bytes of the item
@property(nullable,strong) NSDate *creationDate; //!< Date of creation
@property(nullable,strong) NSDate *lastModified; //!< Date of last modification

@property(nullable,strong) NSDate *lastUsed; //!< Date of last use: updated on local import, local update, download - and via lastModified if that date is more recent.

@property(nullable,strong) OCItemFavorite isFavorite; //!< @1 if this is a favorite, @0 or nil if it isn't

@property(strong,nullable) OCUser *owner; //!< The owner of the item
@property(assign) OCShareTypesMask shareTypesMask; //!< Mask indicating the type of shares (to third parties) for this item. OCShareTypesMaskNone if none.
@property(readonly,nonatomic) BOOL isShareable; //!< YES if this item can be shared (convenience accessor to check if .permissions has OCItemPermissionShareable set)
@property(readonly,nonatomic) BOOL isSharedWithUser; //!< YES if this item has been shared with the user (convenience accessor to check if .permissions has OCItemPermissionShared set)

@property(strong,nullable) NSURL *privateLink; //!< Private link for the item. This property is used as a cache. Please use -[OCCore retrievePrivateLinkForItem:..] to request the private link for an item.

@property(readonly,nonatomic) OCItemThumbnailAvailability thumbnailAvailability; //!< Availability of thumbnails for this item. If OCItemThumbnailAvailabilityUnknown, call -[OCCore retrieveThumbnailFor:resultHandler:] to update it.
@property(nullable,strong,nonatomic) OCItemThumbnail *thumbnail; //!< Thumbnail for the item.

@property(nullable,strong) OCDatabaseID databaseID; //!< OCDatabase-specific ID referencing the item in the database

@property(nullable,strong) NSNumber *quotaBytesRemaining; //!< Remaining space (if a quota is set)
@property(nullable,strong) NSNumber *quotaBytesUsed; //!< Used space (if a quota is set)

@property(readonly,nonatomic) BOOL compactingAllowed; //!< YES if the local copy may be removed during compacting.

+ (OCLocalID)generateNewLocalID; //!< Generates a new, unique OCLocalID

+ (instancetype)placeholderItemOfType:(OCItemType)type;

+ (nullable NSString *)localizedNameForProperty:(OCItemPropertyName)propertyName;

#pragma mark - Sync record tools
- (void)addSyncRecordID:(OCSyncRecordID)syncRecordID activity:(OCItemSyncActivity)activity;
- (void)removeSyncRecordID:(OCSyncRecordID)syncRecordID activity:(OCItemSyncActivity)activity;
- (NSUInteger)countOfSyncRecordsWithSyncActivity:(OCItemSyncActivity)activity;

- (void)prepareToReplace:(OCItem *)item;
- (void)copyFilesystemMetadataFrom:(OCItem *)item;
- (void)copyMetadataFrom:(OCItem *)item except:(nullable NSSet <OCItemPropertyName> *)exceptProperties;

#pragma mark - Local attribute access
- (nullable id)valueForLocalAttribute:(OCLocalAttribute)localAttribute;
- (void)setValue:(nullable id)value forLocalAttribute:(OCLocalAttribute)localAttribute;

#pragma mark - File tools
- (nullable OCFile *)fileWithCore:(OCCore *)core; //!< OCFile instance generated from the data in the OCItem. Returns nil if the item doesn't reference a local file. To test local availability of a file, use -[OCCore localCopyOfItem:] instead of this method.

#pragma mark - Serialization tools
+ (nullable instancetype)itemFromSerializedData:(NSData *)serializedData;
- (nullable NSData *)serializedData;

@end

extern OCFileID   OCFileIDPlaceholderPrefix; //!< FileID placeholder prefix for items that are not in sync with the server, yet
extern OCFileETag OCFileETagPlaceholder; //!< ETag placeholder value for items that are not in sync with the server, yet

extern OCLocalAttribute OCLocalAttributeFavoriteRank; //!< attribute for storing the favorite rank
extern OCLocalAttribute OCLocalAttributeTagData; //!< attribute for storing tag data

extern OCItemPropertyName OCItemPropertyNameLocalAttributes;
extern OCItemPropertyName OCItemPropertyNameLastModified;

// Supported by OCQueryCondition SQLBuilder
extern OCItemPropertyName OCItemPropertyNameType; //!< Supported by OCQueryCondition SQLBuilder
extern OCItemPropertyName OCItemPropertyNamePath; //!< Supported by OCQueryCondition SQLBuilder
extern OCItemPropertyName OCItemPropertyNameName; //!< Supported by OCQueryCondition SQLBuilder
extern OCItemPropertyName OCItemPropertyNameMIMEType; //!< Supported by OCQueryCondition SQLBuilder
extern OCItemPropertyName OCItemPropertyNameSize; //!< Supported by OCQueryCondition SQLBuilder
extern OCItemPropertyName OCItemPropertyNameCloudStatus; //!< Supported by OCQueryCondition SQLBuilder
extern OCItemPropertyName OCItemPropertyNameHasLocalAttributes; //!< Supported by OCQueryCondition SQLBuilder
extern OCItemPropertyName OCItemPropertyNameLastUsed; //!< Supported by OCQueryCondition SQLBuilder
extern OCItemPropertyName OCItemPropertyNameIsFavorite; //!< Supported by OCQueryCondition SQLBuilder
extern OCItemPropertyName OCItemPropertyNameLocallyModified; //!< Supported by OCQueryCondition SQLBuilder
extern OCItemPropertyName OCItemPropertyNameLocalRelativePath; //!< Supported by OCQueryCondition SQLBuilder

NS_ASSUME_NONNULL_END
