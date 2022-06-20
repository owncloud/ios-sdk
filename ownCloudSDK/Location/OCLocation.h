//
//  OCLocation.h
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

#import <Foundation/Foundation.h>
#import "OCTypes.h"
#import "OCBookmark.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCLocationString; //!< DriveID + path encoded into a single string. Format should be assumed private.

typedef NSData* OCLocationData;

@interface OCLocation : NSObject <NSSecureCoding, NSCopying>

@property(class,strong,readonly,nonatomic) OCLocation *legacyRootLocation;
+ (OCLocation *)legacyRootPath:(nullable OCPath)path;

+ (OCLocation *)withVFSPath:(nullable OCPath)path;

@property(strong,nullable) OCBookmarkUUID bookmarkUUID; //!< UUID of the account containing the location. A nil value represents the account managed by the receiver of the location.

@property(strong,nullable,nonatomic) OCDriveID driveID; //!< DriveID of the drive. A nil value indicates a legacy WebDAV endpoint path.
@property(strong,nullable) OCPath path; //!< The path of the location inside the drive and account.

- (instancetype)initWithDriveID:(nullable OCDriveID)driveID path:(nullable OCPath)path;
- (instancetype)initWithBookmarkUUID:(nullable OCBookmarkUUID)bookmarkUUID driveID:(nullable OCDriveID)driveID path:(nullable OCPath)path;

#pragma mark - Tools
@property(strong,readonly,nonatomic) OCLocation *parentLocation;
@property(strong,nullable,readonly,nonatomic) OCLocation *normalizedDirectoryPathLocation;
@property(strong,nullable,readonly,nonatomic) OCLocation *normalizedFilePathLocation;
@property(strong,nullable,readonly,nonatomic) NSString *lastPathComponent;

@property(readonly,nonatomic) BOOL isRoot;

+ (BOOL)driveID:(nullable OCDriveID)driveID1 isEqualDriveID:(nullable OCDriveID)driveID2;

- (BOOL)isLocatedIn:(nullable OCLocation *)location;

#pragma mark - En-/Decoding as unified string
@property(strong,readonly,nonatomic) OCLocationString string;
+ (nullable instancetype)fromString:(OCLocationString)string;

#pragma mark - En-/Decoding to opaque data
@property(strong,readonly,nullable,nonatomic) OCLocationData data;
+ (nullable instancetype)fromData:(OCLocationData)data;

@end

extern NSString* OCLocationDataTypeIdentifier;

NS_ASSUME_NONNULL_END
