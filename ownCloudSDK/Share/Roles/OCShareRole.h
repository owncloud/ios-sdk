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
#import "OCShareTypes.h"
#import "OCLocation.h"

typedef NSString* OCShareRoleType NS_TYPED_ENUM;

NS_ASSUME_NONNULL_BEGIN

@interface OCShareRole : NSObject

@property(strong,nullable) OCShareRoleID identifier; //!< ocis role ID

@property(strong) OCShareRoleType type; //!< Abstract, internal type (like "editor" or "viewer")

@property(assign) OCShareTypesMask shareTypes; //!< Types of share (link, group, user, …)

@property(assign) OCSharePermissionsMask permissions; //!< Mask of permissions set on the share
@property(assign) OCSharePermissionsMask customizablePermissions; //!< Mask of permissions the user is allowed to customize
@property(assign) OCLocationType locations; //!< Mask of OCLocationTypes this role can be used with

@property(strong,nullable) NSNumber *weight; //!< Weight for ordering

@property(strong) OCSymbolName symbolName;
@property(strong) NSString *localizedName;
@property(strong) NSString *localizedDescription;

- (instancetype)initWithIdentifier:(nullable OCShareRoleID)identifier type:(OCShareRoleType)type shareTypes:(OCShareTypesMask)shareTypes permissions:(OCSharePermissionsMask)permissions customizablePermissions:(OCSharePermissionsMask)customizablePermissions locations:(OCLocationType)locations symbolName:(OCSymbolName)symbolName localizedName:(NSString *)localizedName localizedDescription:(NSString *)localizedDescription;

@end

extern OCShareRoleType OCShareRoleTypeInternal;
extern OCShareRoleType OCShareRoleTypeViewer;
extern OCShareRoleType OCShareRoleTypeUploader;
extern OCShareRoleType OCShareRoleTypeEditor;
extern OCShareRoleType OCShareRoleTypeContributor;
extern OCShareRoleType OCShareRoleTypeManager;
extern OCShareRoleType OCShareRoleTypeCustom;

// as per https://github.com/owncloud/web/blob/6983ef727ea25430d57c7625ec53f0b249132246/packages/web-client/src/graph/drives/drives.ts#L9
extern OCShareRoleID OCShareRoleIDManagerV1; //!< v1 role ID (textual)
extern OCShareRoleID OCShareRoleIDViewerV1; //!< v1 role ID (textual)
extern OCShareRoleID OCShareRoleIDEditorV1; //!< v1 role ID (textual)

extern OCShareRoleID OCShareRoleIDManager; //!< v2 role ID (uuid)
extern OCShareRoleID OCShareRoleIDViewer; //!< v2 role ID (uuid)
extern OCShareRoleID OCShareRoleIDEditor; //!< v2 role ID (uuid)

NS_ASSUME_NONNULL_END
