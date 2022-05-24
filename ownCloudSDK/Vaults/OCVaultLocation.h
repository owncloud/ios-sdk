//
//  OCVaultLocation.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 26.04.22.
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
#import "OCBookmark.h"
#import "OCTypes.h"
#import "OCVFSTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCVaultLocation : NSObject

@property(strong, nullable) OCBookmarkUUID bookmarkUUID;
@property(strong, nullable) OCDriveID driveID;
@property(strong, nullable) OCLocalID localID;

@property(assign)	    BOOL isVirtual;
@property(strong, nullable) OCVFSNodeID vfsNodeID;

@property(strong, nullable) NSArray<NSString *> *additionalPathElements;

#pragma mark - VFS item ID
- (nullable instancetype)initWithVFSItemID:(OCVFSItemID)vfsItemID;
@property(readonly,nonatomic) OCVFSItemID vfsItemID;

@end

NS_ASSUME_NONNULL_END
