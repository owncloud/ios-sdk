//
//  NSError+OCISError.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 19.09.22.
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

#import "NSError+OCError.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSError (OCISError)

+ (nullable NSError *)errorFromOCISErrorDictionary:(NSDictionary<NSString *, NSString *> *)ocisErrorDict underlyingError:(nullable NSError *)underlyingError;

@end

extern NSErrorUserInfoKey OCOcisErrorCodeKey;

NS_ASSUME_NONNULL_END
