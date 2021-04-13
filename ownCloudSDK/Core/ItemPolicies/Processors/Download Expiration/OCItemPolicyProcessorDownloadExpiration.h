//
//  OCItemPolicyProcessorDownloadExpiration.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.07.19.
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

@interface OCItemPolicyProcessorDownloadExpiration : OCItemPolicyProcessor

@property(readonly,nonatomic,class,strong) NSNumber *freeDiskSpace;
@property(readonly,nonatomic,class,strong) NSNumber *totalCapacity;

- (instancetype)initWithCore:(OCCore *)core;

@property(readonly,nonatomic,assign) UInt64 minimumTimeSinceLastUsage;	//!< Minimum number of seconds to keep local copies around after they were last used. A value of 0 turns off this feature.

// @property(readonly,nonatomic,assign) UInt64 permanentLocalCopyQuota;	//!< Permanent quota for keeping local copies of files that would otherwise be removed. A value of 0 turns off this feature.
//
// @property(readonly,nonatomic,assign) UInt64 minimumFreeDiskSpace;	//!< Minimum number of bytes to keep free on the device. If non-zero: if .permanentLocalCopyQuota is zero, allows filling up the space until htting the free device space limit. If .permanentLocalCopyQuota is non-zero, will reduce .permanentLocalCopyQuota if the free space is less than .minimumFreeDiskSpace.

@end

extern OCItemPolicyKind OCItemPolicyKindDownloadExpiration;

extern OCClassSettingsKey OCClassSettingsKeyItemPolicyLocalCopyExpirationEnabled;
extern OCClassSettingsKey OCClassSettingsKeyItemPolicyLocalCopyExpiration;

NS_ASSUME_NONNULL_END
