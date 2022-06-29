//
//  OCDataSourceComposition.m
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

#import "OCDataSourceComposition.h"
#import "NSArray+OCFiltering.h"
#import "OCMacros.h"

#pragma mark - Record definition
@interface OCDataSourceCompositionRecord : NSObject

@property(assign) NSRange itemRange;

@property(weak,nullable) OCDataSourceComposition *composition;

@property(strong,readonly) OCDataSource *source;
@property(strong,nullable) OCDataSourceSubscription *subscription;
@property(strong,nullable) OCDataSourceSnapshot *activeSnapshot;

@property(copy,nullable) OCDataSourceItemFilter filter;
@property(copy,nullable) OCDataSourceItemComparator sortComparator;

@property(assign) BOOL include;

@property(assign) BOOL hasUpdates;

- (instancetype)initWithSource:(OCDataSource *)source composition:(OCDataSourceComposition *)composition;

@end

#pragma mark - Composition
@interface OCDataSourceComposition ()
{
	NSMutableArray<OCDataItemReference> *_combinedItemReferences;
	NSMutableArray<OCDataSourceCompositionRecord *> *_sourceRecords;

	NSMapTable<OCDataItemReference, OCDataSourceCompositionRecord *> *_compositionRecordByItemReference;

	dispatch_queue_t _compositionQueue;

	BOOL _compositionNeedsUpdate;

	BOOL _supressNeedsCompositionUpdates;
}
@end

@implementation OCDataSourceComposition

+ (dispatch_queue_t)sharedCompositionQueue
{
	static dispatch_once_t onceToken;
	static dispatch_queue_t sharedCompositionQueue;

	dispatch_once(&onceToken, ^{
		sharedCompositionQueue = dispatch_queue_create("DataSourceComposition queue", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
	});

	return (sharedCompositionQueue);
}

- (instancetype)initWithSources:(NSArray<OCDataSource *> *)sources applyCustomizations:(nullable void (^)(OCDataSourceComposition * _Nonnull))customizationApplicator
{
	if ((self = [super init]) != nil)
	{
		_combinedItemReferences = [NSMutableArray new];
		_sourceRecords = [NSMutableArray new];

		_compositionQueue = OCDataSourceComposition.sharedCompositionQueue;

		if (customizationApplicator != nil)
		{
			// Set up sources without initial composition update
			_supressNeedsCompositionUpdates = YES;

			self.sources = sources;

			// Apply customizations
			customizationApplicator(self);

			// Initial composition update
			_supressNeedsCompositionUpdates = NO;
			[self setNeedsCompositionUpdate];
		}
		else
		{
			// Set up sources with initial composition update
			self.sources = sources;
		}
	}

	return (self);
}

#pragma mark - Filter and sorting helpers
+ (OCDataSourceItemFilter)itemFilterWithItemRetrieval:(BOOL)itemRetrieval fromRecordFilter:(OCDataSourceItemRecordFilter)itemRecordFilter
{
	return (^(OCDataSource *source, OCDataItemReference itemRef) {
		__block OCDataItemRecord *record;

		record = [source recordForItemRef:itemRef error:NULL];

		if ((record.item == nil) && itemRetrieval)
		{
			OCSyncExec(RetrieveItem, {
				[record retrieveItemWithCompletionHandler:^(NSError * _Nullable error, OCDataItemRecord * _Nullable retrievedRecord) {
					OCSyncExecDone(RetrieveItem);

					record = retrievedRecord;
				}];
			});
		}

		return (itemRecordFilter(record));
	});
}

+ (OCDataSourceItemComparator)itemComparatorWithItemRetrieval:(BOOL)itemRetrieval fromRecordComparator:(OCDataSourceItemRecordComparator)itemRecordComparator
{
	return (^(OCDataSource *source1, OCDataItemReference itemRef1, OCDataSource *source2, OCDataItemReference itemRef2) {
		__block OCDataItemRecord *record1, *record2;

		record1 = [source1 recordForItemRef:itemRef1 error:NULL];
		if ((record1.item == nil) && itemRetrieval)
		{
			OCSyncExec(RetrieveItem, {
				[record1 retrieveItemWithCompletionHandler:^(NSError * _Nullable error, OCDataItemRecord * _Nullable retrievedRecord) {
					OCSyncExecDone(RetrieveItem);

					record1 = retrievedRecord;
				}];
			});
		}

		record2 = [source2 recordForItemRef:itemRef2 error:NULL];
		if ((record2.item == nil) && itemRetrieval)
		{
			OCSyncExec(RetrieveItem, {
				[record2 retrieveItemWithCompletionHandler:^(NSError * _Nullable error, OCDataItemRecord * _Nullable retrievedRecord) {
					OCSyncExecDone(RetrieveItem);

					record2 = retrievedRecord;
				}];
			});
		}

		return (itemRecordComparator(record1,record2));
	});
}

- (void)setFilter:(OCDataSourceItemFilter)filter
{
	_filter = [filter copy];
	[self setNeedsCompositionUpdate];
}

- (void)setSortComparator:(OCDataSourceItemComparator)sortComparator
{
	_sortComparator = [sortComparator copy];
	[self setNeedsCompositionUpdate];
}

- (void)setSortComparator:(OCDataSourceItemComparator)sortComparator forSource:(OCDataSource *)source
{
	@synchronized(_sourceRecords)
	{
		[self recordForSource:source].sortComparator = sortComparator;
	}

	[self setNeedsCompositionUpdate];
}

- (void)setFilter:(OCDataSourceItemFilter)filter forSource:(OCDataSource *)source
{
	@synchronized(_sourceRecords)
	{
		[self recordForSource:source].filter = filter;
	}

	[self setNeedsCompositionUpdate];
}

- (void)setInclude:(BOOL)include forSource:(OCDataSource *)source
{
	BOOL didChange = NO;

	@synchronized(_sourceRecords)
	{
		if ([self recordForSource:source].include != include)
		{
			[self recordForSource:source].include = include;
			didChange = YES;
		}
	}

	if (didChange)
	{
		[self setNeedsCompositionUpdate];
	}
}

#pragma mark - Sources
- (NSMutableArray<OCDataSourceCompositionRecord *> *)_sourceRecordsForNewSources:(NSArray<OCDataSource *> *)sources
{
	NSMutableArray<OCDataSourceCompositionRecord *> *sourceRecords = [NSMutableArray new];

	for (OCDataSource *source in sources)
	{
		OCDataSourceCompositionRecord *record;

		if ((record = [self recordForSource:source]) == nil)
		{
			record = [[OCDataSourceCompositionRecord alloc] initWithSource:source composition:self];
		}

		if (record != nil)
		{
			[sourceRecords addObject:record];
		}
	}

	return (sourceRecords);
}

- (void)setSources:(NSArray<OCDataSource *> *)sources
{
	NSMutableArray<OCDataSourceCompositionRecord *> *newSourceRecords = [self _sourceRecordsForNewSources:sources];

	@synchronized(_sourceRecords)
	{
		[_sourceRecords setArray:newSourceRecords];
	}

	[self setNeedsCompositionUpdate];
}

- (void)addSources:(NSArray<OCDataSource *> *)sources
{
	NSMutableArray<OCDataSourceCompositionRecord *> *newSourceRecords = [self _sourceRecordsForNewSources:sources];

	if (newSourceRecords.count > 0)
	{
		@synchronized(_sourceRecords)
		{
			[_sourceRecords addObjectsFromArray:newSourceRecords];
		}

		[self setNeedsCompositionUpdate];
	}
}

- (void)insertSources:(NSArray<OCDataSource *> *)sources after:(OCDataSource *)otherSource
{
	NSMutableArray<OCDataSourceCompositionRecord *> *newSourceRecords = [self _sourceRecordsForNewSources:sources];

	if (newSourceRecords.count > 0)
	{
		NSLog(@"BEF: Before: %@", _sourceRecords);

		@synchronized(_sourceRecords)
		{
			NSUInteger afterIndex = [_sourceRecords indexOfObjectPassingTest:^BOOL(OCDataSourceCompositionRecord * _Nonnull sourceRecord, NSUInteger idx, BOOL * _Nonnull stop) {
				return (sourceRecord.source == otherSource);
			}];

			if (afterIndex != NSNotFound)
			{
				[_sourceRecords insertObjects:newSourceRecords atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(afterIndex, newSourceRecords.count)]];
			}
		}

		NSLog(@"BEF: After: %@", _sourceRecords);

		[self setNeedsCompositionUpdate];
	}
}

- (void)removeSources:(NSArray<OCDataSource *> *)removeSources
{
	@synchronized(_sourceRecords)
	{
		NSArray<OCDataSourceCompositionRecord *> *filteredRecords = nil;

		filteredRecords = [_sourceRecords filteredArrayUsingBlock:^BOOL(OCDataSourceCompositionRecord * _Nonnull sourceRecord, BOOL * _Nonnull stop) {
			return ([removeSources indexOfObjectIdenticalTo:sourceRecord.source] == NSNotFound);
		}];

		[_sourceRecords setArray:filteredRecords];
	}

	[self setNeedsCompositionUpdate];
}

#pragma mark - Composition
- (dispatch_queue_t)compositionQueue
{
	return (_compositionQueue);
}

- (OCDataSourceCompositionRecord *)recordForSource:(OCDataSource *)source
{
	@synchronized(_sourceRecords)
	{
		return ([_sourceRecords firstObjectMatching:^BOOL(OCDataSourceCompositionRecord * _Nonnull object) {
			return (object.source == source);
		}]);
	}
}

- (void)setNeedsCompositionUpdate
{
	if (_supressNeedsCompositionUpdates)
	{
		return;
	}

	@synchronized(self)
	{
		_compositionNeedsUpdate = YES;
	}

	__weak OCDataSourceComposition *weakSelf = self;

	dispatch_async(_compositionQueue, ^{
		OCDataSourceComposition *strongSelf;

		if ((strongSelf = weakSelf) != nil)
		{
			BOOL doUpdate = NO;

			@synchronized(strongSelf)
			{
				if (strongSelf->_compositionNeedsUpdate)
				{
					doUpdate = YES;
					strongSelf->_compositionNeedsUpdate = NO;
				}
			}

			if (doUpdate)
			{
				[self _updateComposition];
			}
		}
	});
}

- (void)_updateComposition
{
	NSMutableArray<OCDataItemReference> *composedItemReferences = [NSMutableArray new];
	NSMutableSet<OCDataItemReference> *updatedItemReferences = [NSMutableSet new];
	NSArray<OCDataSourceCompositionRecord *> *sourceRecords;
	NSMapTable<OCDataItemReference, OCDataSourceCompositionRecord *> *compositionRecordByItemReference = nil;

	@synchronized(_sourceRecords)
	{
		sourceRecords = [_sourceRecords copy];
	}

	if (_sortComparator != nil)
	{
		compositionRecordByItemReference = [NSMapTable strongToWeakObjectsMapTable];
	}

	for (OCDataSourceCompositionRecord *record in sourceRecords)
	{
		NSRange itemRange = NSMakeRange(composedItemReferences.count, 0);

		// Skip records that shouldn't be included
		if (!record.include) {
			record.itemRange = NSMakeRange(NSUIntegerMax, 0);
			continue;
		}

		// Fetch updates where available
		if (record.hasUpdates)
		{
			@synchronized(record)
			{
				if (record.hasUpdates)
				{
					OCDataSourceSnapshot *snapshot = [record.subscription snapshotResettingChangeTracking:YES];

					record.activeSnapshot = snapshot;
					record.hasUpdates = NO;

					[updatedItemReferences unionSet:snapshot.updatedItems];
				}
			}
		}

		// Add to composed array
		NSArray<OCDataItemReference> *snapshotItems;

		if ((snapshotItems = record.activeSnapshot.items) != nil)
		{
			if (record.filter != nil)
			{
				// Apply source-specific filter
				snapshotItems = [snapshotItems filteredArrayUsingBlock:^BOOL(OCDataItemReference  _Nonnull itemRef, BOOL * _Nonnull stop) {
					if (record.filter(record.source, itemRef))
					{
						return (YES);
					}

					[updatedItemReferences removeObject:itemRef];

					return (NO);
				}];
			}

			if (record.sortComparator != nil)
			{
				// Apply source-specific sorting
				snapshotItems = [snapshotItems sortedArrayUsingComparator:^NSComparisonResult(OCDataItemReference itemRef1, OCDataItemReference itemRef2) {
					return (record.sortComparator(record.source, itemRef1, record.source, itemRef2));
				}];
			}

			if ((_sortComparator != nil) || (_filter != nil))
			{
				for (OCDataItemReference itemRef in snapshotItems)
				{
					BOOL includeItem = YES;

					if (_filter != nil)
					{
						includeItem = _filter(record.source, itemRef);

						if (includeItem)
						{
							// Only add items passing the filter
							[composedItemReferences addObject:itemRef];
						}
						else
						{
							// Remove updates for items that are not in the composed set of items
							[updatedItemReferences removeObject:itemRef];
						}
					}

					if ((_sortComparator != nil) && includeItem)
					{
						[compositionRecordByItemReference setObject:record forKey:itemRef];
					}
				}
			}

			if (_filter == nil)
			{
				[composedItemReferences addObjectsFromArray:snapshotItems];
			}

			itemRange.length = composedItemReferences.count - itemRange.location;
		}

		record.itemRange = itemRange;
	}

	// Propagate updates
	@synchronized(_subscriptions)
	{
		// Make items available for sorting by reference
		_compositionRecordByItemReference = compositionRecordByItemReference;

		// Sort items
		if (_sortComparator != nil)
		{
			[composedItemReferences sortUsingComparator:^NSComparisonResult(OCDataItemReference reference1, OCDataItemReference reference2) {
				return (_sortComparator(self, reference1, self, reference2));
			}];
		}

		// Update data source
		[self setItemReferences:composedItemReferences updated:updatedItemReferences];
	}
}

#pragma mark - Forwarding to underlying data sources
- (OCDataSource *)dataSourceForItemReference:(OCDataItemReference)itemRef
{
	@synchronized(_subscriptions)
	{
		if (_compositionRecordByItemReference != nil)
		{
			return ([_compositionRecordByItemReference objectForKey:itemRef].source);
		}

		NSUInteger itemIndex = [_itemReferences indexOfObject:itemRef];

		if (itemIndex != NSNotFound)
		{
			for (OCDataSourceCompositionRecord *record in _sourceRecords)
			{
				NSRange recordRange = record.itemRange;

				if ((itemIndex >= recordRange.location) &&
				    (itemIndex < (recordRange.location + recordRange.length)))
				{
					return (record.source);
				}
			}
		}
	}

	return (nil);
}

- (nullable OCDataItemRecord *)recordForItemRef:(OCDataItemReference)itemRef error:(NSError * _Nullable * _Nullable)error
{
	OCDataSource *datasource;

	if ((datasource = [self dataSourceForItemReference:itemRef]) != nil)
	{
		return ([datasource recordForItemRef:itemRef error:error]);
	}

	return (nil);
}

- (void)retrieveItemForRef:(OCDataItemReference)reference reusingRecord:(nullable OCDataItemRecord *)reuseRecord completionHandler:(OCDataSourceItemForReferenceCompletionHandler)completionHandler
{
	OCDataSource *datasource;

	if ((datasource = [self dataSourceForItemReference:reference]) != nil)
	{
		return ([datasource retrieveItemForRef:reference reusingRecord:reuseRecord completionHandler:completionHandler]);
	}
}

- (nullable OCDataSource *)dataSourceForChildrenOfItemReference:(OCDataItemReference)itemRef
{
	OCDataSource *datasource;

	if ((datasource = [self dataSourceForItemReference:itemRef]) != nil)
	{
		return ([datasource dataSourceForChildrenOfItemReference:itemRef]);
	}

	return (nil);
}

@end


#pragma mark - Record implementation
@implementation OCDataSourceCompositionRecord

- (instancetype)initWithSource:(OCDataSource *)source composition:(OCDataSourceComposition *)composition
{
	if ((self = [super init]) != nil)
	{
		__weak OCDataSourceCompositionRecord *weakSelf = self;

		_composition = composition;
		_include = YES;

		_source = source;
		_subscription = [source subscribeWithUpdateHandler:^(OCDataSourceSubscription * _Nonnull subscription) {
			[weakSelf updateWithSubscription:subscription];
		} onQueue:composition.compositionQueue trackDifferences:YES performIntialUpdate:YES];
	}

	return (self);
}

- (void)dealloc
{
	[_subscription terminate];
}

- (void)updateWithSubscription:(OCDataSourceSubscription *)subscription
{
	@synchronized(self)
	{
		_hasUpdates = YES;
		[_composition setNeedsCompositionUpdate];
	}
}

@end
