//
//  OCDrive.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 31.01.22.
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
#import "OCQuota.h"
#import "OCDataTypes.h"

@class GADrive;
@class OCLocation;

NS_ASSUME_NONNULL_BEGIN

typedef NSString *OCDriveType;
typedef NSString* OCDriveAlias;

@interface OCDrive : NSObject <NSSecureCoding, OCDataItem, OCDataItemVersion>

@property(strong) OCDriveID identifier;
@property(strong) OCDriveType type;

@property(strong,nullable) NSString *name;
@property(strong,nullable) NSString *desc;

@property(strong,nullable) NSURL *davRootURL;

@property(strong,nullable) OCQuota *quota;

@property(strong,nullable) GADrive *gaDrive;

@property(assign) OCSeed seed;

@property(strong,nonatomic,readonly) OCLocation *rootLocation;
@property(strong,nonatomic,readonly) OCFileETag rootETag;

+ (instancetype)driveFromGADrive:(GADrive *)drive; //!< oCIS drive, initialized from a GADrive instance
+ (instancetype)personalDrive; //!< OC10 root folder drive

- (BOOL)isSubstantiallyDifferentFrom:(OCDrive *)drive;

@end

extern OCDriveType OCDriveTypePersonal;
extern OCDriveType OCDriveTypeVirtual;
extern OCDriveType OCDriveTypeProject;
extern OCDriveType OCDriveTypeShare;

#define OCDriveIDNil ((OCDriveID)NSNull.null)
#define OCDriveIDWrap(driveID) ((OCDriveID)((driveID == nil) ? OCDriveIDNil : driveID))
#define OCDriveIDUnwrap(driveID) ((OCDriveID)(((driveID!=nil) && [driveID isKindOfClass:NSNull.class]) ? nil : driveID))
#define OCDriveIDIsIdentical(driveID1,driveID2) ((OCDriveIDUnwrap(driveID1)==OCDriveIDUnwrap(driveID2)) || [driveID1 isEqual:driveID2])

NS_ASSUME_NONNULL_END

