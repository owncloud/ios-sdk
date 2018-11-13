//
//  OCItem.m
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

#import "OCItem.h"
#import "OCCore.h"
#import "OCCore+FileProvider.h"
#import "OCFile.h"
#import "OCItem+OCItemCreationDebugging.h"

@implementation OCItem

+ (instancetype)placeholderItemOfType:(OCItemType)type
{
	OCItem *item = [OCItem new];

	item.type = type;

	item.eTag = OCFileETagPlaceholder;
	item.fileID = [OCFileIDPlaceholderPrefix stringByAppendingString:NSUUID.UUID.UUIDString];

	return (item);
}

#pragma mark - Serialization tools
+ (instancetype)itemFromSerializedData:(NSData *)serializedData;
{
	if (serializedData != nil)
	{
		return ([NSKeyedUnarchiver unarchiveObjectWithData:serializedData]);
	}

	return (nil);
}

- (NSData *)serializedData
{
	return ([NSKeyedArchiver archivedDataWithRootObject:self]);
}

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInteger:_type    		forKey:@"type"];

	[coder encodeObject:_mimeType 		forKey:@"mimeType"];

	[coder encodeInteger:_status  		forKey:@"status"];

	[coder encodeInteger:_permissions  	forKey:@"permissions"];

	[coder encodeObject:_localRelativePath	forKey:@"localRelativePath"];
	[coder encodeBool:_locallyModified      forKey:@"locallyModified"];

	[coder encodeObject:_remoteItem		forKey:@"remoteItem"];

	[coder encodeObject:_path 		forKey:@"path"];

	[coder encodeObject:_parentFileID	forKey:@"parentFileID"];
	[coder encodeObject:_fileID 		forKey:@"fileID"];
	[coder encodeObject:_eTag 		forKey:@"eTag"];

	[coder encodeObject:_activeSyncRecordIDs forKey:@"activeSyncRecordIDs"];
	[coder encodeInteger:_syncActivity 	forKey:@"syncActivity"];

	[coder encodeInteger:_size  		forKey:@"size"];
	[coder encodeObject:_creationDate	forKey:@"creationDate"];
	[coder encodeObject:_lastModified	forKey:@"lastModified"];

	[coder encodeObject:_isFavorite		forKey:@"isFavorite"];

	[coder encodeObject:_localAttributes 	forKey:@"localAttributes"];
	[coder encodeDouble:_localAttributesLastModified forKey:@"localAttributesLastModified"];

	[coder encodeObject:_shares		forKey:@"shares"];

	[coder encodeObject:_databaseID		forKey:@"databaseID"];
}

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		[self _captureCallstack];

		_thumbnailAvailability = OCItemThumbnailAvailabilityInternal;
	}

	return (self);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		[self _captureCallstack];

		_thumbnailAvailability = OCItemThumbnailAvailabilityInternal;

		_type = [decoder decodeIntegerForKey:@"type"];

		_mimeType = [decoder decodeObjectOfClass:[NSString class] forKey:@"mimeType"];

		_status = [decoder decodeIntegerForKey:@"status"];

		_permissions = [decoder decodeIntegerForKey:@"permissions"];

		_localRelativePath = [decoder decodeObjectOfClass:[NSURL class] forKey:@"localRelativePath"];
		_locallyModified = [decoder decodeBoolForKey:@"locallyModified"];

		_remoteItem = [decoder decodeObjectOfClass:[OCItem class] forKey:@"remoteItem"];

		_path = [decoder decodeObjectOfClass:[NSString class] forKey:@"path"];

		_parentFileID = [decoder decodeObjectOfClass:[NSString class] forKey:@"parentFileID"];
		_fileID = [decoder decodeObjectOfClass:[NSString class] forKey:@"fileID"];
		_eTag = [decoder decodeObjectOfClass:[NSString class] forKey:@"eTag"];

		_activeSyncRecordIDs = [decoder decodeObjectOfClass:[NSArray class] forKey:@"activeSyncRecordIDs"];
		_syncActivity = [decoder decodeIntegerForKey:@"syncActivity"];

		_size = [decoder decodeIntegerForKey:@"size"];
		_creationDate = [decoder decodeObjectOfClass:[NSDate class] forKey:@"creationDate"];
		_lastModified = [decoder decodeObjectOfClass:[NSDate class] forKey:@"lastModified"];

		_isFavorite = [decoder decodeObjectOfClass:[NSNumber class] forKey:@"isFavorite"];

		_localAttributes = [decoder decodeObjectOfClass:[NSMutableDictionary class] forKey:@"localAttributes"];
		_localAttributesLastModified = [decoder decodeDoubleForKey:@"localAttributesLastModified"];

		_shares = [decoder decodeObjectOfClass:[NSArray class] forKey:@"shares"];

		_databaseID = [decoder decodeObjectOfClass:[NSValue class] forKey:@"databaseID"];
	}

	return (self);
}

#pragma mark - Properties
- (NSString *)name
{
	return ([self.path lastPathComponent]);
}

- (void)setETag:(OCFileETag)eTag
{
	_eTag = eTag;
	_versionIdentifier = nil;
}

- (void)setFileID:(OCFileID)fileID
{
	_fileID = fileID;
	_versionIdentifier = nil;
}

- (OCItemVersionIdentifier *)itemVersionIdentifier
{
	if (_versionIdentifier == nil)
	{
		_versionIdentifier = [[OCItemVersionIdentifier alloc] initWithFileID:_fileID eTag:_eTag];
	}

	return (_versionIdentifier);
}

- (BOOL)isPlaceholder
{
	return ([self.eTag isEqualToString:OCFileETagPlaceholder] || [self.fileID hasPrefix:OCFileIDPlaceholderPrefix]);
}

- (OCItemThumbnailAvailability)thumbnailAvailability
{
	if (_thumbnailAvailability == OCItemThumbnailAvailabilityInternal)
	{
		if (_type == OCItemTypeCollection)
		{
			_thumbnailAvailability = OCItemThumbnailAvailabilityNone;
		}
		else
		{
			_thumbnailAvailability = OCItemThumbnailAvailabilityUnknown;

			if (_mimeType != nil)
			{
				if (![OCCore thumbnailSupportedForMIMEType:_mimeType])
				{
					_thumbnailAvailability = OCItemThumbnailAvailabilityNone;
				}
			}
		}
	}

	return (_thumbnailAvailability);
}

- (void)setThumbnail:(OCItemThumbnail *)thumbnail
{
	_thumbnail = thumbnail;

	if (thumbnail != nil)
	{
		_thumbnailAvailability = OCItemThumbnailAvailabilityAvailable;
	}
}

- (id)valueForLocalAttribute:(OCLocalAttribute)localAttribute
{
	@synchronized(self)
	{
		return (_localAttributes[localAttribute]);
	}
}

- (void)setValue:(id)value forLocalAttribute:(OCLocalAttribute)localAttribute
{
	@synchronized(self)
	{
		if (value != nil)
		{
			if (_localAttributes==nil)
			{
				_localAttributes = [NSMutableDictionary new];
			}

			_localAttributes[localAttribute] = value;
		}
		else
		{
			[_localAttributes removeObjectForKey:localAttribute];

			if (_localAttributes.count==0)
			{
				_localAttributes = nil;
			}
		}

		_localAttributesLastModified = NSDate.timeIntervalSinceReferenceDate;
	}
}

#pragma mark - Sync record tools
- (void)addSyncRecordID:(OCSyncRecordID)syncRecordID activity:(OCItemSyncActivity)activity
{
	if (activity != OCItemSyncActivityNone)
	{
		self.syncActivity |= activity;
	}

	if (syncRecordID == nil) { return; }

	[self willChangeValueForKey:@"activeSyncRecordIDs"];

	if (_activeSyncRecordIDs != nil)
	{
		if (![_activeSyncRecordIDs isKindOfClass:[NSMutableArray class]])
		{
			_activeSyncRecordIDs = [_activeSyncRecordIDs mutableCopy];
		}

		[(NSMutableArray *)_activeSyncRecordIDs addObject:syncRecordID];
	}
	else
	{
		_activeSyncRecordIDs = [NSMutableArray arrayWithObject:syncRecordID];
	}

	[self didChangeValueForKey:@"activeSyncRecordIDs"];
}

- (void)removeSyncRecordID:(OCSyncRecordID)syncRecordID activity:(OCItemSyncActivity)activity
{
	if (activity != OCItemSyncActivityNone)
	{
		self.syncActivity &= ~activity;
	}

	if (syncRecordID == nil) { return; }

	[self willChangeValueForKey:@"activeSyncRecordIDs"];

	if (_activeSyncRecordIDs != nil)
	{
		if (![_activeSyncRecordIDs isKindOfClass:[NSMutableArray class]])
		{
			_activeSyncRecordIDs = [_activeSyncRecordIDs mutableCopy];
		}

		if ([_activeSyncRecordIDs containsObject:syncRecordID])
		{
			[(NSMutableArray *)_activeSyncRecordIDs removeObject:syncRecordID];
		}
	}

	if (_activeSyncRecordIDs.count == 0)
	{
		_activeSyncRecordIDs = nil;
	}

	[self didChangeValueForKey:@"activeSyncRecordIDs"];
}

- (void)prepareToReplace:(OCItem *)item
{
	self.databaseID 	  = item.databaseID;

	self.activeSyncRecordIDs  = item.activeSyncRecordIDs;
	self.syncActivity 	  = item.syncActivity;

	if (self.parentFileID == nil)
	{
		self.parentFileID = item.parentFileID;
	}

	// Make sure to use latest version of local attributes
	if (self.localAttributesLastModified < item.localAttributesLastModified)
	{
		self.localAttributes 	  	 = item.localAttributes;
		self.localAttributesLastModified = item.localAttributesLastModified;
	}
}

#pragma mark - File tools
- (OCFile *)fileWithCore:(OCCore *)core
{
	OCFile *file = nil;

	if (self.localRelativePath != nil)
	{
		file = [OCFile new];

		file.url = [core localURLForItem:self];

		file.item = self;
		file.eTag = self.eTag;
		file.fileID = self.fileID;
	}

	return (file);
}

#pragma mark - Description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p, type: %lu, name: %@, path: %@, size: %lu bytes, MIME-Type: %@, Last modified: %@, fileID: %@, parentID: %@%@>", NSStringFromClass(self.class), self, (unsigned long)self.type, self.name, self.path, self.size, self.mimeType, self.lastModified, self.fileID, self.parentFileID, (_removed ? @", removed" : @"")]);
}

@end

OCFileID   OCFileIDPlaceholderPrefix = @"_placeholder_";
OCFileETag OCFileETagPlaceholder = @"_placeholder_";

OCLocalAttribute OCLocalAttributeFavoriteRank = @"_favorite-rank";
OCLocalAttribute OCLocalAttributeTagData = @"_tag-data";

OCItemPropertyName OCItemPropertyNameLastModified = @"lastModified";
OCItemPropertyName OCItemPropertyNameIsFavorite = @"isFavorite";
