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

@implementation OCItem

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

	[coder encodeObject:_fileID 		forKey:@"fileID"];
	[coder encodeObject:_eTag 		forKey:@"eTag"];

	[coder encodeInteger:_size  		forKey:@"size"];
	[coder encodeObject:_lastModified	forKey:@"lastModified"];

	[coder encodeObject:_shares		forKey:@"shares"];
}

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_thumbnailAvailability = OCItemThumbnailAvailabilityInternal;
	}

	return (self);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		_thumbnailAvailability = OCItemThumbnailAvailabilityInternal;

		_type = [decoder decodeIntegerForKey:@"type"];

		_mimeType = [decoder decodeObjectOfClass:[NSString class] forKey:@"mimeType"];

		_status = [decoder decodeIntegerForKey:@"status"];

		_permissions = [decoder decodeIntegerForKey:@"permissions"];

		_localRelativePath = [decoder decodeObjectOfClass:[NSURL class] forKey:@"localRelativePath"];
		_locallyModified = [decoder decodeBoolForKey:@"locallyModified"];

		_remoteItem = [decoder decodeObjectOfClass:[OCItem class] forKey:@"remoteItem"];

		_path = [decoder decodeObjectOfClass:[NSString class] forKey:@"path"];

		_fileID = [decoder decodeObjectOfClass:[NSString class] forKey:@"fileID"];
		_eTag = [decoder decodeObjectOfClass:[NSString class] forKey:@"eTag"];

		_size = [decoder decodeIntegerForKey:@"size"];
		_lastModified = [decoder decodeObjectOfClass:[NSDate class] forKey:@"lastModified"];

		_shares = [decoder decodeObjectOfClass:[NSArray class] forKey:@"shares"];
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

- (OCItemVersionIdentifier *)versionIdentifier
{
	if (_versionIdentifier == nil)
	{
		_versionIdentifier = [[OCItemVersionIdentifier alloc] initWithFileID:_fileID eTag:_eTag];
	}

	return (_versionIdentifier);
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

#pragma mark - Description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p, type: %lu, name: %@, path: %@, size: %lu bytes, MIME-Type: %@, Last modified: %@>", NSStringFromClass(self.class), self, (unsigned long)self.type, self.name, self.path, self.size, self.mimeType, self.lastModified]);
}

@end
