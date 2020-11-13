//
//  OCClassSettings+Validation.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.10.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCClassSettings.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCClassSettings (Validation)

- (void)validateValue:(id)value forClass:(Class<OCClassSettingsSupport>)settingsClass key:(OCClassSettingsKey)key resultHandler:(void(^)(NSError * _Nullable error, id _Nullable value))resultHandler;

- (nullable NSDictionary<OCClassSettingsKey, NSError *> *)validateDictionary:(NSMutableDictionary<OCClassSettingsKey, id> *)settingsDict forClass:(Class<OCClassSettingsSupport>)settingsClass updateCache:(BOOL)updateCacheOfValidValues;

@end

NS_ASSUME_NONNULL_END
