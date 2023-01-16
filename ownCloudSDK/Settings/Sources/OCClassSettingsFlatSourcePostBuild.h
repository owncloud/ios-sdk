//
//  OCClassSettingsFlatSourcePostBuild.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 16.01.23.
//  Copyright © 2023 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2023, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <ownCloudSDK/ownCloudSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface OCClassSettingsFlatSourcePostBuild : OCClassSettingsFlatSource <OCClassSettingsSupport>

@property(class,nonatomic,readonly) OCClassSettingsFlatSourcePostBuild *sharedPostBuildSettings;

- (nullable NSError *)setValue:(nullable id)value forFlatIdentifier:(OCClassSettingsFlatIdentifier)flatID;
- (nullable id)valueForFlatIdentifier:(OCClassSettingsFlatIdentifier)flatID;

- (nullable NSError *)clear;

@end

extern OCClassSettingsSourceIdentifier OCClassSettingsSourceIdentifierPostBuild;

extern OCClassSettingsIdentifier OCClassSettingsIdentifierPostBuildSettings;
extern OCClassSettingsKey OCClassSettingsKeyPostBuildAllowedFlatIdentifiers;

NS_ASSUME_NONNULL_END
