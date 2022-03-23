//
//  DataSourceTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 20.03.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>

@interface DataSourceTests : XCTestCase

@end

@implementation DataSourceTests

- (void)testDataSourceInitialSnapshotAndBasicMutations
{
	OCDataSource *source = [OCDataSource new];
	OCDataSourceSnapshot *snapshot;

	OCDataSourceSubscription *subscription = [source subscribeWithUpdateHandler:^(OCDataSourceSubscription * _Nonnull subscription) {
		OCLog(@"Subscription notified of update");
	} trackDifferences:YES];

	// Take snapshot
	snapshot = [subscription snapshotResettingChangeTracking:YES];
	XCTAssert( ([snapshot.items isEqual:@[ ] ]) );
	XCTAssert( ([snapshot.addedItems isEqual:[NSSet set]]) );
	XCTAssert( ([snapshot.updatedItems isEqual:[NSSet set]]) );
	XCTAssert( ([snapshot.removedItems isEqual:[NSSet set]]) );

	// Add "a"
	[source setItemReferences:@[@"a"] updated:nil];
	snapshot = [subscription snapshotResettingChangeTracking:YES];
	XCTAssert( ([snapshot.items isEqual:@[ @"a" ] ]) );
	XCTAssert( ([snapshot.addedItems isEqual:[NSSet setWithArray:@[ @"a" ]]]) );
	XCTAssert( ([snapshot.updatedItems isEqual:[NSSet set]]) );
	XCTAssert( ([snapshot.removedItems isEqual:[NSSet set]]) );

	// Add "b"
	[source setItemReferences:@[@"a",@"b"] updated:nil];
	snapshot = [subscription snapshotResettingChangeTracking:YES];
	XCTAssert( ([snapshot.items isEqual:@[ @"a",@"b" ] ]) );
	XCTAssert( ([snapshot.addedItems isEqual:[NSSet setWithArray:@[ @"b" ]]]) );
	XCTAssert( ([snapshot.updatedItems isEqual:[NSSet set]]) );
	XCTAssert( ([snapshot.removedItems isEqual:[NSSet set]]) );

	// Remove "b"
	[source setItemReferences:@[@"a"] updated:nil];
	snapshot = [subscription snapshotResettingChangeTracking:YES];
	XCTAssert( ([snapshot.items isEqual:@[ @"a" ] ]) );
	XCTAssert( ([snapshot.addedItems isEqual:[NSSet set]]) );
	XCTAssert( ([snapshot.updatedItems isEqual:[NSSet set]]) );
	XCTAssert( ([snapshot.removedItems isEqual:[NSSet setWithArray:@[ @"b" ]]]) );

	// Update "a"
	[source setItemReferences:@[@"a"] updated:[NSSet setWithArray:@[ @"a" ]]];
	snapshot = [subscription snapshotResettingChangeTracking:YES];
	XCTAssert( ([snapshot.items isEqual:@[ @"a" ] ]) );
	XCTAssert( ([snapshot.addedItems isEqual:[NSSet set]]) );
	XCTAssert( ([snapshot.updatedItems isEqual:[NSSet setWithArray:@[ @"a" ]]]) );
	XCTAssert( ([snapshot.removedItems isEqual:[NSSet set]]) );
}

- (void)testDataSourceInitialSnapshotAndTrickyMutations
{
	OCDataSource *source = [OCDataSource new];
	OCDataSourceSnapshot *snapshot;

	[source setItemReferences:@[@"a", @"b", @"c"] updated:nil];

	OCDataSourceSubscription *subscription = [source subscribeWithUpdateHandler:^(OCDataSourceSubscription * _Nonnull subscription) {
		OCLog(@"Subscription notified of update");
	} trackDifferences:YES];

	// Take snapshot, check if contents is in it
	snapshot = [subscription snapshotResettingChangeTracking:YES];
	XCTAssert( ([snapshot.items isEqual:@[ @"a", @"b", @"c" ] ]) );
	XCTAssert( ([snapshot.addedItems isEqual:[NSSet set]]) );
	XCTAssert( ([snapshot.updatedItems isEqual:[NSSet set]]) );
	XCTAssert( ([snapshot.removedItems isEqual:[NSSet set]]) );

	// Add "d", update "b"
	[source setItemReferences:@[@"a", @"b", @"c", @"d"] updated:[NSSet setWithArray:@[ @"b" ]]];
	snapshot = [subscription snapshotResettingChangeTracking:YES];
	XCTAssert( ([snapshot.items isEqual:@[ @"a", @"b", @"c", @"d" ] ]) );
	XCTAssert( ([snapshot.addedItems isEqual:[NSSet setWithArray:@[ @"d" ] ]]) );
	XCTAssert( ([snapshot.updatedItems isEqual:[NSSet setWithArray:@[ @"b" ] ]]) );
	XCTAssert( ([snapshot.removedItems isEqual:[NSSet set]]) );

	// update "a", update "c"
	[source setItemReferences:@[@"a", @"b", @"c", @"d"] updated:[NSSet setWithArray:@[ @"a", @"c" ]]];
	snapshot = [subscription snapshotResettingChangeTracking:YES];
	XCTAssert( ([snapshot.items isEqual:@[ @"a", @"b", @"c", @"d" ] ]) );
	XCTAssert( ([snapshot.addedItems isEqual:[NSSet set]]) );
	XCTAssert( ([snapshot.updatedItems isEqual:[NSSet setWithArray:@[ @"a", @"c" ] ]]) );
	XCTAssert( ([snapshot.removedItems isEqual:[NSSet set]]) );

	// Remove "d"
	[source setItemReferences:@[@"a", @"b", @"c"] updated:nil];
	snapshot = [subscription snapshotResettingChangeTracking:YES];
	XCTAssert( ([snapshot.items isEqual:@[ @"a", @"b", @"c" ] ]) );
	XCTAssert( ([snapshot.addedItems isEqual:[NSSet set ]]) );
	XCTAssert( ([snapshot.updatedItems isEqual:[NSSet set ]]) );
	XCTAssert( ([snapshot.removedItems isEqual:[NSSet setWithArray:@[ @"d" ] ]]) );

	// Remove "c"
	[source setItemReferences:@[@"a", @"b"] updated:nil];
	// Add "c"
	[source setItemReferences:@[@"a", @"b", @"c"] updated:nil];
	snapshot = [subscription snapshotResettingChangeTracking:YES];
	XCTAssert( ([snapshot.items isEqual:@[ @"a", @"b", @"c" ] ]) );
	XCTAssert( ([snapshot.addedItems isEqual:[NSSet set ]]) );
	XCTAssert( ([snapshot.updatedItems isEqual:[NSSet setWithArray:@[@"c"] ]]) );
	XCTAssert( ([snapshot.removedItems isEqual:[NSSet set ]]) );

	// Add "d"
	[source setItemReferences:@[@"a", @"b", @"c", @"d"] updated:nil];
	// Remove "d"
	[source setItemReferences:@[@"a", @"b", @"c"] updated:nil];
	// Add "d"
	[source setItemReferences:@[@"a", @"b", @"c", @"d"] updated:nil];
	snapshot = [subscription snapshotResettingChangeTracking:YES];
	XCTAssert( ([snapshot.items isEqual:@[ @"a", @"b", @"c", @"d" ] ]) );
	XCTAssert( ([snapshot.addedItems isEqual:[NSSet setWithArray:@[@"d"] ]]) );
	XCTAssert( ([snapshot.updatedItems isEqual:[NSSet set ]]) );
	XCTAssert( ([snapshot.removedItems isEqual:[NSSet set ]]) );

	// Remove "d"
	[source setItemReferences:@[@"a", @"b", @"c"] updated:nil];
	// Add "d"
	[source setItemReferences:@[@"a", @"b", @"c", @"d"] updated:nil];
	// Remove "d"
	[source setItemReferences:@[@"a", @"b", @"c"] updated:nil];
	snapshot = [subscription snapshotResettingChangeTracking:YES];
	XCTAssert( ([snapshot.items isEqual:@[ @"a", @"b", @"c" ] ]) );
	XCTAssert( ([snapshot.addedItems isEqual:[NSSet set ]]) );
	XCTAssert( ([snapshot.updatedItems isEqual:[NSSet set ]]) );
	XCTAssert( ([snapshot.removedItems isEqual:[NSSet setWithArray:@[@"d"] ]]) );

	// Update "d"
	[source setItemReferences:@[@"a", @"b", @"c", @"d"] updated:[NSSet setWithArray:@[ @"d" ]]];
	// Remove "d"
	[source setItemReferences:@[@"a", @"b", @"c"] updated:nil];
	snapshot = [subscription snapshotResettingChangeTracking:YES];
	XCTAssert( ([snapshot.items isEqual:@[ @"a", @"b", @"c" ] ]) );
	XCTAssert( ([snapshot.addedItems isEqual:[NSSet set ]]) );
	XCTAssert( ([snapshot.updatedItems isEqual:[NSSet set ]]) );
	XCTAssert( ([snapshot.removedItems isEqual:[NSSet set ]]) );

	// Add "d" + remove "c"
	[source setItemReferences:@[@"a", @"b", @"d"] updated:nil];
	snapshot = [subscription snapshotResettingChangeTracking:YES];
	XCTAssert( ([snapshot.items isEqual:@[ @"a", @"b", @"d" ] ]) );
	XCTAssert( ([snapshot.addedItems isEqual:[NSSet setWithArray:@[@"d"] ]]) );
	XCTAssert( ([snapshot.updatedItems isEqual:[NSSet set]]) );
	XCTAssert( ([snapshot.removedItems isEqual:[NSSet setWithArray:@[@"c"] ]]) );

	// Add + Update "c"
	[source setItemReferences:@[@"a", @"b", @"c", @"d"] updated:[NSSet setWithArray:@[ @"c" ]]];
	// Remove "c"
	[source setItemReferences:@[@"a", @"b", @"d"] updated:nil];
	snapshot = [subscription snapshotResettingChangeTracking:YES];
	XCTAssert( ([snapshot.items isEqual:@[ @"a", @"b", @"d" ] ]) );
	XCTAssert( ([snapshot.addedItems isEqual:[NSSet set ]]) );
	XCTAssert( ([snapshot.updatedItems isEqual:[NSSet set ]]) );
	XCTAssert( ([snapshot.removedItems isEqual:[NSSet set ]]) );

	// Update non-existant "f"
	[source setItemReferences:@[@"a", @"b", @"d"] updated:[NSSet setWithArray:@[ @"f" ]]];
	snapshot = [subscription snapshotResettingChangeTracking:YES];
	XCTAssert( ([snapshot.items isEqual:@[ @"a", @"b", @"d" ] ]) );
	XCTAssert( ([snapshot.addedItems isEqual:[NSSet set]]) );
	XCTAssert( ([snapshot.updatedItems isEqual:[NSSet set]]) );
	XCTAssert( ([snapshot.removedItems isEqual:[NSSet set]]) );

	// Add "c", remove "b" and update "d" and "a"
	[source setItemReferences:@[@"a", @"c", @"d"] updated:[NSSet setWithArray:@[ @"d", @"a" ]]];
	snapshot = [subscription snapshotResettingChangeTracking:YES];
	XCTAssert( ([snapshot.items isEqual:@[ @"a", @"c", @"d" ] ]) );
	XCTAssert( ([snapshot.addedItems isEqual:[NSSet setWithObject:@"c"]]) );
	XCTAssert( ([snapshot.updatedItems isEqual:[NSSet setWithObjects:@"a", @"d", nil]]) );
	XCTAssert( ([snapshot.removedItems isEqual:[NSSet setWithObject:@"b"]]) );

	// Set existing items
	[source setItemReferences:@[@"a", @"c", @"d"] updated:nil];
	snapshot = [subscription snapshotResettingChangeTracking:YES];
	XCTAssert( ([snapshot.items isEqual:@[ @"a", @"c", @"d" ] ]) );
	XCTAssert( ([snapshot.addedItems isEqual:[NSSet set]]) );
	XCTAssert( ([snapshot.updatedItems isEqual:[NSSet set]]) );
	XCTAssert( ([snapshot.removedItems isEqual:[NSSet set]]) );
}

- (void)testDataSourceInitialSnapshotAndOrderMutations
{
	OCDataSource *source = [OCDataSource new];
	OCDataSourceSnapshot *snapshot;

	[source setItemReferences:@[@"a", @"b", @"c"] updated:nil];

	OCDataSourceSubscription *subscription = [source subscribeWithUpdateHandler:^(OCDataSourceSubscription * _Nonnull subscription) {
		OCLog(@"Subscription notified of update");
	} trackDifferences:YES];

	// Take snapshot, check if contents is in it
	snapshot = [subscription snapshotResettingChangeTracking:YES];
	XCTAssert( ([snapshot.items isEqual:@[ @"a", @"b", @"c" ] ]) );
	XCTAssert( ([snapshot.addedItems isEqual:[NSSet set]]) );
	XCTAssert( ([snapshot.updatedItems isEqual:[NSSet set]]) );
	XCTAssert( ([snapshot.removedItems isEqual:[NSSet set]]) );

	// Change order, check if any changes are reported (there shouldn't be)
	[source setItemReferences:@[@"a", @"c", @"b"] updated:nil];
	snapshot = [subscription snapshotResettingChangeTracking:YES];
	XCTAssert( ([snapshot.items isEqual:@[ @"a", @"c", @"b"] ]) );
	XCTAssert( ([snapshot.addedItems isEqual:[NSSet set]]) );
	XCTAssert( ([snapshot.updatedItems isEqual:[NSSet set]]) );
	XCTAssert( ([snapshot.removedItems isEqual:[NSSet set]]) );
}

@end
