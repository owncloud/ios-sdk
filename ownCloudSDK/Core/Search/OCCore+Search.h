//
//  OCCore+Search.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 31.10.24.
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

#import "OCCore.h"
#import "OCSearchResult.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCCore (Search)

- (nullable OCSearchResult *)searchFilesWithPattern:(NSString *)pattern limit:(nullable NSNumber *)limit options:(nullable NSDictionary<OCConnectionOptionKey,id> *)options;

@end

NS_ASSUME_NONNULL_END
