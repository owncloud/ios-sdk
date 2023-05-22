//
//  OCResourceRequestURLItem.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.09.22.
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

#import <ownCloudSDK/ownCloudSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface OCResourceRequestURLItem : OCResourceRequest

@property(strong,readonly,nonatomic) NSURL *url;

@property(class,strong,readonly,nonatomic) OCResourceVersion daySpecificVersion;	//!< Generated resource version that changes every day. Can be used to force resource refreshes once every day.
@property(class,strong,readonly,nonatomic) OCResourceVersion weekSpecificVersion;	//!< Generated resource version that changes every week. Can be used to force resource refreshes once every week.
@property(class,strong,readonly,nonatomic) OCResourceVersion monthSpecificVersion;	//!< Generated resource version that changes every month. Can be used to force resource refreshes once every month.
@property(class,strong,readonly,nonatomic) OCResourceVersion yearSpecificVersion;	//!< Generated resource version that changes every year. Can be used to force resource refreshes once every year.

+ (instancetype)requestURLItem:(NSURL *)url identifier:(nullable OCResourceIdentifier)identifier version:(nullable OCResourceVersion)version structureDescription:(nullable OCResourceStructureDescription)structureDescription waitForConnectivity:(BOOL)waitForConnectivity changeHandler:(nullable OCResourceRequestChangeHandler)changeHandler;

@end

NS_ASSUME_NONNULL_END
