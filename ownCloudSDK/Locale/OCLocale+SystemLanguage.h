//
//  OCLocale+SystemLanguage.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.10.22.
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

#import "OCLocale.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCLocale (SystemLanguage)

@property(strong,readonly,nonatomic,nullable) NSString *acceptLanguageString;
@property(strong,readonly,nonatomic,nullable) NSString *primaryUserLanguage;

@end

NS_ASSUME_NONNULL_END
