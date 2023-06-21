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

typedef NSString *OCDriveType NS_TYPED_ENUM;
typedef NSString* OCDriveAlias;

typedef NSString *OCDriveSpecialType NS_TYPED_ENUM;

typedef NS_ENUM(NSInteger, OCDriveDetachedState)
{
	OCDriveDetachedStateNone,

	OCDriveDetachedStateNew,		//!< Initial state when a drive has been detected as detached, before further examination
	OCDriveDetachedStateHasUserChanges,	//!< The detached drive has user changes and should be retained (not implemented yet)
	OCDriveDetachedStateRetain,		//!< The detached drive should be retained (not implemented yet)
	OCDriveDetachedStateItemsRemoved,	//!< The detached drive's items have been marked as removed in the database and both database and files will be disposed of through the vacuum item policy
	OCDriveDetachedStateDisposable		//!< The detached drive and its items on disk and in the database can be disposed of (not implemented yet)
};

@interface OCDrive : NSObject <NSSecureCoding, OCDataItem, OCDataItemVersioning>

@property(strong) OCDriveID identifier;
@property(strong) OCDriveType type;

@property(readonly,nonatomic,nullable) OCDriveSpecialType specialType; //!< Convenience accessor to determine if a drive is the personal or shares jail drive.

@property(readonly,nonatomic) BOOL isDeactivated;

@property(strong,nullable,nonatomic) NSString *name;
@property(strong,nullable) NSString *desc;

@property(strong,nullable) NSURL *davRootURL;

@property(strong,nullable) GAQuota *quota;

@property(strong,nullable) GADrive *gaDrive;

@property(assign) OCSeed seed;

@property(strong,nonatomic,readonly) OCLocation *rootLocation;
@property(strong,nonatomic,readonly) OCFileETag rootETag;

#pragma mark - Detached management
@property(readonly,nonatomic) BOOL isDetached;
@property(assign) OCDriveDetachedState detachedState;
@property(strong,nullable) NSDate *detachedSinceDate;

#pragma mark - Instantiation
+ (instancetype)driveFromGADrive:(GADrive *)drive; //!< oCIS drive, initialized from a GADrive instance

#pragma mark - Comparison
- (BOOL)isSubstantiallyDifferentFrom:(OCDrive *)drive;

@end

extern OCDriveType OCDriveTypePersonal; //!< A users personal space
extern OCDriveType OCDriveTypeVirtual;	//!< Virtual space containing all items shared with the user
extern OCDriveType OCDriveTypeProject;	//!< Regular spaces
extern OCDriveType OCDriveTypeMountpoint; //!< Accepted shared items
extern OCDriveType OCDriveTypeShare;

extern OCDriveSpecialType OCDriveSpecialTypePersonal;	//!< The user's personal space
extern OCDriveSpecialType OCDriveSpecialTypeShares;	//!< The Shares Jail space
extern OCDriveSpecialType OCDriveSpecialTypeSpace;	//!< Regular project spaces

extern OCDriveID OCDriveIDSharesJail; //!< The static UUID of the Shares Jail

#define OCDriveIDNil ((OCDriveID)NSNull.null)
#define OCDriveIDWrap(driveID) ((OCDriveID)((driveID == nil) ? OCDriveIDNil : driveID))
#define OCDriveIDUnwrap(driveID) ((OCDriveID)(((driveID!=nil) && [driveID isKindOfClass:NSNull.class]) ? nil : driveID))
#define OCDriveIDIsIdentical(driveID1,driveID2) ((OCDriveIDUnwrap(driveID1)==OCDriveIDUnwrap(driveID2)) || [driveID1 isEqual:driveID2])

NS_ASSUME_NONNULL_END

