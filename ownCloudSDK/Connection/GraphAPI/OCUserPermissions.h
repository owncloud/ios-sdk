//
//  OCUserPermissions.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.02.25.
//  Copyright © 2025 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2025, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>

typedef NSString* OCUserPermissionIdentifier; //!< String representing a permission ("right") the user has to perform specific actions on the server

NS_ASSUME_NONNULL_BEGIN

@interface OCUserPermissions : NSObject

// MARK: - Initializer
- (instancetype)initWith:(NSArray<OCUserPermissionIdentifier> *)permissionIDs;

// MARK: - Permissions
@property(readonly,strong) NSArray<OCUserPermissionIdentifier> *identifiers;
@property(readonly) BOOL canCreateSpaces;
@property(readonly) BOOL canEditSpaces;
@property(readonly) BOOL canDisableSpaces;

@end

NS_ASSUME_NONNULL_END
