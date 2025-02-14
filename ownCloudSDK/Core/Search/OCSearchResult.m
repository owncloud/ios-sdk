//
//  OCSearchResult.m
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

#import "OCSearchResult.h"
#import "OCDataSourceArray.h"
#import "OCMacros.h"
#import "OCLocation.h"
#import "OCItem+OCDataItem.h"

@implementation OCSearchResult
{
	NSMapTable<OCLocation *, OCCoreItemTracking> *_itemTrackingByLocation;
	NSMutableArray<OCItem *> *_resultItems;
}

- (instancetype)initWithKQLQuery:(OCKQLQuery)kqlQuery core:(OCCore *)core
{
	if ((self = [super init]) != nil)
	{
		_itemTrackingByLocation = [NSMapTable strongToStrongObjectsMapTable];
		_resultItems = [NSMutableArray new];

		self.core = core;
		self.kqlQuery = kqlQuery;
		self.results = [[OCDataSourceArray alloc] initWithItems:nil];
		[((OCDataSourceArray *)self.results) setVersionedItems:@[]];
		self.results.state = OCDataSourceStateLoading;
	}

	return (self);
}

- (void)dealloc
{
	if (!self.progress.cancelled)
	{
		[self.progress cancel];
	}
}

- (void)cancel
{
	[self.progress cancel];
}

- (void)_handleResultEvent:(OCEvent *)event
{
	NSArray<OCItem *> *searchResults = OCTypedCast(event.result, NSArray);
	OCDataSourceArray *searchResultDatasource = (OCDataSourceArray *)self.results;

	self.results.state = OCDataSourceStateIdle;

	if (event.error != nil) {
		self.error = event.error;
		OCLogError(@"Search ended with error: %@", event.error);
		return;
	}

	if (searchResults != nil)
	{
		for (OCItem *item in searchResults)
		{
			OCDriveID itemDriveID = item.driveID;
			OCPath itemPath = item.path;

			if ((itemDriveID != nil) && (itemPath != nil))
			{
				OCLocation *location = [[OCLocation alloc] initWithDriveID:itemDriveID path:itemPath];
				OCCoreItemTracking itemTracker = [self.core trackItemAtLocation:location trackingHandler:^(NSError * _Nullable error, OCItem * _Nullable item, BOOL isInitial) {
					if (item != nil)
					{
						@synchronized(self) {
							[self->_resultItems addObject:item];
							[searchResultDatasource setVersionedItems:self->_resultItems];

							OCLogDebug(@"Result Items: %@", self->_resultItems);
						}
					}

					if ((error != nil) || (item != nil))
					{
						// Stop tracking item when there's an error or the item has been located
						@synchronized(self) {
							[self->_itemTrackingByLocation removeObjectForKey:location];
						}
					}
				}];

				// Keep tracking alive until it delivers a result
				@synchronized(self) {
					[_itemTrackingByLocation setObject:itemTracker forKey:location];
				}
			}
		}
	}
}

@end
