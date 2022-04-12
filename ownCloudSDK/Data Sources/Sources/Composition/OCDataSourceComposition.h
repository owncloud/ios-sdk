//
//  OCDataSourceComposition.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 08.04.22.
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

#import "OCDataSourceArray.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCDataSourceComposition : OCDataSourceArray

@property(strong,nonatomic) NSArray<OCDataSource *> *sources;

#pragma mark - Filter and sorting helpers
+ (OCDataSourceItemFilter)itemFilterWithItemRetrieval:(BOOL)itemRetrieval fromRecordFilter:(OCDataSourceItemRecordFilter)itemRecordFilter; //!< Adds boilerplate code to itemRecordFilter to retrieve the item records for the item references. If itemRetrieval is true, will synchronously retrieve the item before invoking itemRecordFilter.
+ (OCDataSourceItemComparator)itemComparatorWithItemRetrieval:(BOOL)itemRetrieval fromRecordComparator:(OCDataSourceItemRecordComparator)itemRecordComparator; //!< Adds boilerplate code to itemRecordComparator to retrieve the item records for the item references. If itemRetrieval is true, will synchronously retrieve the items before invoking itemRecordComparator.

#pragma mark - Initialization
- (instancetype)initWithSources:(NSArray<OCDataSource *> *)sources applyCustomizations:(nullable void(^)(OCDataSourceComposition *))customizationApplicator; //!< Creates a new data source composed from other data sources. The passed customizationApplicator will be called before the initial composition, allowing to apply customizations like filters and sort comparators.

#pragma mark - Lookup
- (nullable OCDataSource *)dataSourceForItemReference:(OCDataItemReference)itemRef; //!< Returns the data source that stores itemRef - or nil if none of the data sources contained the item

#pragma mark - Filtering and sorting (merged item set)
@property(copy,nullable,nonatomic) OCDataSourceItemFilter filter; //!< Filter to apply to the combined item set
@property(copy,nullable,nonatomic) OCDataSourceItemComparator sortComparator; //!< Sort comparator to apply to the combined item set

#pragma mark - Filtering and sorting (individual sources)
- (void)setFilter:(nullable OCDataSourceItemFilter)filter forSource:(OCDataSource *)source; //!< Filter to apply to an individual source
- (void)setSortComparator:(nullable OCDataSourceItemComparator)sortComparator forSource:(OCDataSource *)source; //!< Filter to apply to an individual source

@end

NS_ASSUME_NONNULL_END
