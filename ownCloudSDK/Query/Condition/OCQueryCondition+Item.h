//
//  OCQueryCondition+Item.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 19.03.19.
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

#import "OCQueryCondition.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCQueryCondition (Item)

- (BOOL)fulfilledByItem:(OCItem *)item; //!< Returns YES if the provided item fulfills the condition, NO otherwise.

- (nullable NSComparator)itemComparator; //!< Returns a comparator sorting items by the property specified by .sortBy and in .sortAscending order.

@end

NS_ASSUME_NONNULL_END
