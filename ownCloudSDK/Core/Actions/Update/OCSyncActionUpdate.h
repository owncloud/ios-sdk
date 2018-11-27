//
//  OCSyncActionUpdate.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 09.11.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2018, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCSyncAction.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCSyncActionUpdate : OCSyncAction

@property(nullable,strong) OCItem *archivedItemVersion;
@property(strong) NSArray <OCItemPropertyName> *updateProperties;

- (instancetype)initWithItem:(OCItem *)item updateProperties:(NSArray <OCItemPropertyName> *)properties;

@end

NS_ASSUME_NONNULL_END
