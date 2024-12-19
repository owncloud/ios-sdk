//
//  OCODataResponse.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 16.12.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCODataTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCODataResponse : NSObject

@property(nullable,strong) NSError *error;
@property(nullable,strong) id result;

@property(nullable,strong) OCODataLibreGraphObjects libreGraphObjects; //!< (Decoded or raw) objects added in responses starting with "@libre.graph."

- (nonnull instancetype)initWithError:(nullable NSError *)error result:(nullable id)result libreGraphObjects:(nullable OCODataLibreGraphObjects)libreGraphObjects;

@end

NS_ASSUME_NONNULL_END
