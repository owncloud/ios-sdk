//
//  GAPermission+SharePermission.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 18.12.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "GAPermission.h"
#import "OCSharePermission.h"

NS_ASSUME_NONNULL_BEGIN

@interface GAPermission (SharePermission)

- (nullable NSArray<OCSharePermission *> *)sharePermissionsUsingRoleDefinitions:(nullable NSArray<GAUnifiedRoleDefinition *> *)roleDefinitions;

@end

NS_ASSUME_NONNULL_END
