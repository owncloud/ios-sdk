//
//  OCQueryFilter.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.02.18.
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

#import <Foundation/Foundation.h>

@class OCQuery;
@class OCItem;
@class OCQueryFilter;

#pragma mark - Protocol
@protocol OCQueryFilter <NSObject>

- (BOOL)query:(OCQuery *)query shouldIncludeItem:(OCItem *)item; //!< Returns YES if the item should be part of the query result, NO if it should not be.

@optional
- (NSArray <OCItem *> *)query:(OCQuery *)query filterItems:(NSArray <OCItem *> *)items; //!< Returns only those items that should be included in the query result.

@end

#pragma mark - Types
typedef NSString* OCQueryFilterIdentifier; //!< NSString representing a query filter's identifier.
typedef BOOL(^OCQueryFilterHandler)(OCQuery *query, OCQueryFilter *filter, OCItem *item);  //!< Block used to filter query results. Returns YES if an item should be included in the results, NO otherwise.

#pragma mark - Convenience class
@interface OCQueryFilter : NSObject <OCQueryFilter>
{
	OCQueryFilterHandler _filterHandler;
}

@property(copy) OCQueryFilterHandler filterHandler;

+ (instancetype)filterWithHandler:(OCQueryFilterHandler)filterHandler; //!< Returns an auto-released, block-based query filter.

@end
