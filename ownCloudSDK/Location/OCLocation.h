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

@interface OCLocation : NSObject <NSSecureCoding, NSCopying>

@property(strong,nullable) OCBookmarkUUID bookmarkUUID; //!< UUID of the account containing the location. A nil value represents the account managed by the receiver of the location.

@property(strong,nullable) OCDriveID driveID; //!< DriveID of the drive. A nil value indicates a legacy WebDAV endpoint path.
@property(strong,nullable) OCPath path; //!< The path of the location inside the drive and account.

- (instancetype)initWithDriveID:(nullable OCDriveID)driveID path:(nullable OCPath)path;

#pragma mark - En-/Decoding as unified string
@property(strong,readonly,nonatomic) OCLocationString string;
+ (nullable instancetype)fromString:(OCLocationString)string;

@end

NS_ASSUME_NONNULL_END
