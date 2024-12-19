//
//  OCShare+GraphAPI.h
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

#import "OCShare.h"
#import "GAPermission.h"
#import "GAPermission+SharePermission.h"
#import "OCLocation.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCShare (GraphAPI)

+ (nonnull instancetype)shareFromGAPermission:(nonnull GAPermission *)gaPermission roleDefinitions:(NSArray<GAUnifiedRoleDefinition *> *)gaRoleDefinitions forLocation:(nonnull OCLocation *)location item:(nullable OCItem *)item category:(OCShareCategory)category;

@end

NS_ASSUME_NONNULL_END
