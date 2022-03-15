//
//  OCExtension+ServerLocator.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 09.11.21.
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

#import "OCServerLocator.h"
#import "OCExtension.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCExtension (ServerLocator)

+ (instancetype)serverLocatorExtensionWithIdentifier:(OCServerLocatorIdentifier)identifier locations:(NSArray <OCExtensionLocationIdentifier> *)locationIdentifiers metadata:(nullable OCExtensionMetadata)metadata provider:(OCServerLocator * _Nullable(^)(OCExtension *extension, OCExtensionContext *context, NSError * _Nullable * _Nullable error))provider;

@end

NS_ASSUME_NONNULL_END
