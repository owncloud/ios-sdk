//
//  OCShareRole.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 13.10.22.
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
#import "OCSymbol.h"
#import "OCShare.h"
#import "OCLocation.h"

typedef NSString* OCShareRoleType NS_TYPED_ENUM;

NS_ASSUME_NONNULL_BEGIN

@interface OCShareRole : NSObject

@property(strong) OCShareRoleType type; //!< Abstract, internal type (like "editor" or "viewer")

@property(assign) OCShareTypesMask shareTypes; //!< Types of share (link, group, user, …)

@property(assign) OCSharePermissionsMask permissions; //!< Mask of permissions set on the share
@property(assign) OCSharePermissionsMask customizablePermissions; //!< Mask of permissions the user is allowed to customize
@property(assign) OCLocationType locations; //!< Mask of OCLocationTypes this role can be used with

@property(strong) OCSymbolName symbolName;
@property(strong) NSString *localizedName;
@property(strong) NSString *localizedDescription;

- (instancetype)initWithType:(OCShareRoleType)type shareTypes:(OCShareTypesMask)shareTypes permissions:(OCSharePermissionsMask)permissions customizablePermissions:(OCSharePermissionsMask)customizablePermissions locations:(OCLocationType)locations symbolName:(OCSymbolName)symbolName localizedName:(NSString *)localizedName localizedDescription:(NSString *)localizedDescription;

@end

extern OCShareRoleType OCShareRoleTypeInternal;
extern OCShareRoleType OCShareRoleTypeViewer;
extern OCShareRoleType OCShareRoleTypeUploader;
extern OCShareRoleType OCShareRoleTypeEditor;
extern OCShareRoleType OCShareRoleTypeContributor;
extern OCShareRoleType OCShareRoleTypeManager;
extern OCShareRoleType OCShareRoleTypeCustom;

NS_ASSUME_NONNULL_END
