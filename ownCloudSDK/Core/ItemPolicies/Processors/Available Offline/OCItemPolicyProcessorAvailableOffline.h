//
//  OCItemPolicyProcessorAvailableOffline.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.07.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCItemPolicyProcessor.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCItemPolicyProcessorAvailableOffline : OCItemPolicyProcessor

- (instancetype)initWithCore:(OCCore *)core;

@end

extern OCItemPolicyKind OCItemPolicyKindAvailableOffline; //!< Available Offline: items covered by this policy are pre-downloaded to be available offline.

NS_ASSUME_NONNULL_END
