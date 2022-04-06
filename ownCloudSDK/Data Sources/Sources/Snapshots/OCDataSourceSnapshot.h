//
//  OCDataSourceSnapshot.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.03.22.
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

#import <Foundation/Foundation.h>
#import "OCDataTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCDataSourceSnapshot : NSObject

@property(assign) NSUInteger numberOfItems;

@property(strong) NSArray<OCDataItemReference> *items; //!< The current item references at the time of snapshot in their then current order

@property(strong,nullable) NSSet<OCDataItemReference> *addedItems; //!< Added items since last snapshot
@property(strong,nullable) NSSet<OCDataItemReference> *updatedItems; //!< Updated items since last snapshot
@property(strong,nullable) NSSet<OCDataItemReference> *removedItems; //!< Removed items since last snapshot

@property(strong,nullable) NSDictionary<OCDataSourceSpecialItem, OCDataItemReference> *specialItems; //!< The current special item references at the time of snapshot

@end

NS_ASSUME_NONNULL_END
