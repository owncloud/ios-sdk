//
//  OCLocation.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.02.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCLocation.h"
#import "OCMacros.h"
#import "NSString+OCPath.h"
#import "OCDrive.h"
#import "OCLogger.h"
#import "OCDataRenderer.h"
#import "OCDataConverter.h"
#import "OCDataItemPresentable.h"
#import "OCSymbol.h"

@interface OCLocation ()
{
	OCLocation *_parentLocation;
	OCLocation *_normalizedDirectoryPathLocation;
	OCLocation *_normalizedFilePathLocation;
}
@end

@implementation OCLocation

+ (OCLocation *)legacyRootLocation
{
	return ([[OCLocation alloc] initWithDriveID:nil path:@"/"]);
}

+ (OCLocation *)legacyRootPath:(nullable OCPath)path
{
	return ([[OCLocation alloc] initWithDriveID:nil path:path]);
}

+ (OCLocation *)withVFSPath:(nullable OCPath)path
{
	return ([[OCLocation alloc] initWithDriveID:nil path:path]);
}

- (instancetype)initWithDriveID:(nullable OCDriveID)driveID path:(nullable OCPath)path
{
	return ([self initWithBookmarkUUID:nil driveID:driveID path:path]);
}

- (instancetype)initWithBookmarkUUID:(nullable OCBookmarkUUID)bookmarkUUID driveID:(nullable OCDriveID)driveID path:(nullable OCPath)path
{
	if ((self = [super init]) != nil)
	{
		_bookmarkUUID = bookmarkUUID;
		self.driveID = driveID;
		_path = path;
	}

	return (self);
}

- (void)setDriveID:(OCDriveID)driveID
{
	if ((driveID != nil) && ([driveID isKindOfClass:NSNull.class]))
	{
		driveID = nil;
	}

	_driveID = driveID;
}

#pragma mark - Tools
- (OCLocation *)parentLocation
{
	if (_parentLocation == nil)
	{
		OCPath parentPath;

		if ((parentPath = _path.parentPath) != nil)
		{
			_parentLocation = [[OCLocation alloc] initWithBookmarkUUID:_bookmarkUUID driveID:_driveID path:parentPath];
		}
	}

	return (_parentLocation);
}

- (OCLocation *)normalizedDirectoryPathLocation
{
	if (_normalizedDirectoryPathLocation == nil)
	{
		OCPath normalizedDirectoryPath;

		if ((normalizedDirectoryPath = _path.normalizedDirectoryPath) != nil)
		{
			_normalizedDirectoryPathLocation = [[OCLocation alloc] initWithBookmarkUUID:_bookmarkUUID driveID:_driveID path:normalizedDirectoryPath];
		}
	}

	return (_normalizedDirectoryPathLocation);
}

- (OCLocation *)normalizedFilePathLocation
{
	if (_normalizedFilePathLocation == nil)
	{
		OCPath normalizedFilePath;

		if ((normalizedFilePath = _path.normalizedFilePath) != nil)
		{
			_normalizedFilePathLocation = [[OCLocation alloc] initWithBookmarkUUID:_bookmarkUUID driveID:_driveID path:normalizedFilePath];
		}
	}

	return (_normalizedFilePathLocation);
}

- (NSString *)lastPathComponent
{
	return (_path.lastPathComponent);
}

- (BOOL)isRoot
{
	return (_path.isRootPath);
}

- (OCLocationType)type
{
	if (_path != nil)
	{
		if (_path.isNormalizedDirectoryPath)
		{
			if (_driveID != nil)
			{
				if (_path.isRootPath)
				{
					return (OCLocationTypeDrive);
				}
			}

			return (OCLocationTypeFolder);
		}

		return (OCLocationTypeFile);
	}

	if (_driveID != nil)
	{
		return (OCLocationTypeDrive);
	}

	if (_bookmarkUUID != nil)
	{
		return (OCLocationTypeAccount);
	}

	return (OCLocationTypeUnknown);
}

+ (BOOL)driveID:(nullable OCDriveID)driveID1 isEqualDriveID:(nullable OCDriveID)driveID2
{
	driveID1 = OCDriveIDUnwrap(driveID1);
	driveID2 = OCDriveIDUnwrap(driveID2);

	return ((driveID1 == driveID2) || [driveID1 isEqual:driveID2]);
}

- (BOOL)isLocatedIn:(nullable OCLocation *)location
{
	if ((location == nil) || (location.path == nil) || (_path == nil)) { return (NO); }

	if ([OCLocation driveID:location.driveID isEqualDriveID:_driveID])
	{
		return ([_path hasPrefix:location.path] && location.path.isNormalizedDirectoryPath);
	}

	return (NO);
}

#pragma mark - String composition / decomposition
- (OCLocationString)string
{
	// Format: BOOKMARKUUID;DRIVEID:PATH
	//	- ";" is the devider between BOOKMARKUUID and DRIVEID
	//	- ":" is the devider between DRIVEID and PATH
	//	- missing elements are encoded as empty string ("")
	return ([NSString stringWithFormat:@";%@:%@", ((_driveID != nil) ? _driveID : @""), ((_path != nil) ? _path : @"")]);
}

+ (instancetype)fromString:(OCLocationString)string
{
	NSRange semicolonRange = [string rangeOfString:@";"];

	if (semicolonRange.location != NSNotFound)
	{
		NSRange colonDividerRange = [string rangeOfString:@":"];

		if (colonDividerRange.location != NSNotFound)
		{
			NSString *bookmarkUUIDString = (semicolonRange.location > 0) ? [string substringWithRange:NSMakeRange(1, semicolonRange.location)] : nil;
			NSString *driveID = (colonDividerRange.location > (semicolonRange.location+semicolonRange.length)) ? [string substringWithRange:NSMakeRange((semicolonRange.location+semicolonRange.length), colonDividerRange.location-(semicolonRange.location+semicolonRange.length))] : nil;
			NSString *path = ((colonDividerRange.location+colonDividerRange.length) < string.length) ? [string substringFromIndex:colonDividerRange.location+colonDividerRange.length] : nil;

			OCLocation *location;

			location = [[self alloc] initWithDriveID:driveID path:path];
			if (bookmarkUUIDString != nil)
			{
				location.bookmarkUUID = [[NSUUID alloc] initWithUUIDString:bookmarkUUIDString];
			}

			return (location);
		}
	}

	return (nil);
}

#pragma mark - En-/Decoding to opaque data
- (OCLocationData)data
{
	NSError *error = nil;
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self requiringSecureCoding:YES error:&error];

	if (error != nil)
	{
		OCLogError(@"Serialization of %@ to data failed with error: %@", self, error);
	}

	return (data);
}

+ (nullable instancetype)fromData:(OCLocationData)data
{
	NSError *error = nil;
	OCLocation *location = [NSKeyedUnarchiver unarchivedObjectOfClass:OCLocation.class fromData:data error:&error];

	if (error != nil)
	{
		OCLogError(@"Deserialization of data to OCLocation failed with error: %@", error);
	}

	return (location);
}

#pragma mark - Secure coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		_bookmarkUUID = [decoder decodeObjectOfClass:NSUUID.class forKey:@"bookmarkUUID"];
		_driveID = [decoder decodeObjectOfClass:NSString.class forKey:@"driveID"];
		_path = [decoder decodeObjectOfClass:NSString.class forKey:@"path"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_bookmarkUUID forKey:@"bookmarkUUID"];
	[coder encodeObject:_driveID forKey:@"driveID"];
	[coder encodeObject:_path forKey:@"path"];
}

#pragma mark - Copying
- (id)copyWithZone:(NSZone *)zone
{
	OCLocation *location = [OCLocation new];

	location->_bookmarkUUID = _bookmarkUUID;
	location->_driveID = _driveID;
	location->_path = _path;

	return (location);
}

#pragma mark - Description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p%@%@>", NSStringFromClass(self.class), self,
		OCExpandVar(driveID),
		OCExpandVar(path)
	]);
}

#pragma mark - Comparison
- (NSUInteger)hash
{
	return (_driveID.hash ^ _path.hash);
}

- (BOOL)isEqual:(id)object
{
	OCLocation *otherLocation = OCTypedCast(object, OCLocation);

	if (otherLocation != nil)
	{
		#define compareVar(var) ((otherLocation->var == var) || [otherLocation->var isEqual:var])

		if (compareVar(_driveID) && compareVar(_path))
		{
			if (_driveID != nil)
			{
				// If driveID is set and identical, assume the _bookmarkUUID is identical
				// if one location has it set and the other hasn't
				if (((_bookmarkUUID != nil) && (otherLocation->_bookmarkUUID == nil)) ||
				    ((_bookmarkUUID == nil) && (otherLocation->_bookmarkUUID != nil)))
				{
					return (YES);
				}
			}

			// Compare _bookmarkUUID for identity
			return (compareVar(_bookmarkUUID));
		}
	}

	return (NO);
}

#pragma mark - OCDataItem
- (OCDataItemType)dataItemType
{
	return (OCDataItemTypeLocation);
}

- (OCDataItemReference)dataItemReference
{
	return (self.string);
}

#pragma mark - OCDataItemVersioning
- (OCDataItemVersion)dataItemVersion
{
	// Version remains the same as the reference changes when the content changes
	return (@(0));
}

#pragma mark - OCDataConverter for OCLocation
+ (void)load
{
	OCDataConverter *locationToPresentableConverter;

	locationToPresentableConverter = [[OCDataConverter alloc] initWithInputType:OCDataItemTypeLocation outputType:OCDataItemTypePresentable conversion:^id _Nullable(OCDataConverter * _Nonnull converter, OCLocation * _Nullable inLocation, OCDataRenderer * _Nullable renderer, NSError * _Nullable __autoreleasing * _Nullable outError, OCDataViewOptions  _Nullable options) {
		OCDataItemPresentable *presentable = nil;

		if (inLocation != nil)
		{
			presentable = [[OCDataItemPresentable alloc] initWithItem:inLocation];
			presentable.title = inLocation.lastPathComponent;

			switch (inLocation.type)
			{
				case OCLocationTypeFile:
					presentable.image = [OCSymbol iconForSymbolName:@"doc"];
				break;

				case OCLocationTypeDrive:
					presentable.image = [OCSymbol iconForSymbolName:@"square.grid.2x2"];
				break;

				default:
				case OCLocationTypeFolder:
					if (inLocation.isRoot)
					{
						if (inLocation.driveID == nil)
						{
							// Identical to ocis
							// presentable.title = OCLocalized(@"Personal");
							// presentable.image = [OCSymbol iconForSymbolName:@"person"];

							// OC10 style
							presentable.title = OCLocalized(@"Files");
							presentable.image = [OCSymbol iconForSymbolName:@"folder"];
						}
						else
						{
							presentable.image = [OCSymbol iconForSymbolName:@"square.grid.2x2"];
						}
					}
					else
					{
						presentable.image = [OCSymbol iconForSymbolName:@"folder"];
					}
				break;

				case OCLocationTypeAccount:
					presentable.image = [OCSymbol iconForSymbolName:@"person"];
				break;
			}
		}

		return (presentable);
	}];

	[OCDataRenderer.defaultRenderer addConverters:@[
		locationToPresentableConverter
	]];
}

@end

NSString* OCLocationDataTypeIdentifier = @"com.owncloud.ios-app.location-data";
