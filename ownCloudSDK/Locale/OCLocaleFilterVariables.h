//
//  OCLocaleFilterVariables.h
//  OCLocaleFilterVariables
//
//  Created by Felix Schwarz on 16.10.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCLocaleFilter.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSString * _Nullable(^OCLocaleFilterVariableSource)(void);

@interface OCLocaleFilterVariables : OCLocaleFilter

@property(class,readonly,nonatomic,strong) OCLocaleFilterVariables *shared;

- (void)setVariable:(NSString *)variableName value:(nullable NSString *)value;
- (void)setVariable:(NSString *)variableName source:(nullable OCLocaleFilterVariableSource)source;

@end

extern OCLocaleOptionKey OCLocaleOptionKeyVariables;

NS_ASSUME_NONNULL_END
