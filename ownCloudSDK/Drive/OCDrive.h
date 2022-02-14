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

@class GADrive;

NS_ASSUME_NONNULL_BEGIN

typedef NSString *OCDriveType;

@interface OCDrive : NSObject <NSSecureCoding>

@property(strong) OCDriveID identifier;
@property(strong) OCDriveType type;

@property(strong,nullable) NSString* name;

@property(strong,nullable) NSURL *davRootURL;

@property(strong,nullable) OCQuota *quota;

@property(strong,nullable) GADrive *gDrive;

@property(assign) OCSeed seed;

+ (instancetype)driveFromGDrive:(GADrive *)drive; //!< oCIS drive, initialized from a GADrive instance
+ (instancetype)personalDrive; //!< OC10 root folder drive

@end

extern OCDriveType OCDriveTypePersonal;
extern OCDriveType OCDriveTypeVirtual;
extern OCDriveType OCDriveTypeProject;
extern OCDriveType OCDriveTypeShare;

NS_ASSUME_NONNULL_END

