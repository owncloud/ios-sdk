//
//  OCExtension+HostSimulation.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 12.10.20.
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

#import "OCExtension.h"
#import "OCConnection.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCHostSimulationIdentifier NS_TYPED_EXTENSIBLE_ENUM;

@interface OCExtension (HostSimulation)

+ (instancetype)hostSimulationExtensionWithIdentifier:(OCHostSimulationIdentifier)identifier locations:(NSArray <OCExtensionLocationIdentifier> *)locationIdentifiers metadata:(nullable OCExtensionMetadata)metadata provider:(id<OCConnectionHostSimulator> _Nullable(^)(OCExtension *extension, OCExtensionContext *context, NSError * _Nullable * _Nullable error))provider;

@end

NS_ASSUME_NONNULL_END
