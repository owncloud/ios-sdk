//
//  DataSourceTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 20.03.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>

OCDataItemType DataTypeA = @"A";
OCDataItemType DataTypeB = @"B";
OCDataItemType DataTypeC = @"C";
OCDataItemType DataTypeD = @"D";
OCDataItemType DataTypeE = @"E";

@interface TypeA2BConverter : OCDataConverter
@end

@interface TypeB2CConverter : OCDataConverter
@end

@interface TypeC2DConverter : OCDataConverter
@end

@interface TypeD2EConverter : OCDataConverter
@end

@interface TypeB2DConverter : OCDataConverter
@end

@implementation TypeA2BConverter
-(OCDataItemType)inputType { return (DataTypeA); }
-(OCDataItemType)outputType { return (DataTypeB); }
@end

@implementation TypeB2CConverter
-(OCDataItemType)inputType { return (DataTypeB); }
-(OCDataItemType)outputType { return (DataTypeC); }
@end

@implementation TypeC2DConverter
-(OCDataItemType)inputType { return (DataTypeC); }
-(OCDataItemType)outputType { return (DataTypeD); }
@end

@implementation TypeD2EConverter
-(OCDataItemType)inputType { return (DataTypeD); }
-(OCDataItemType)outputType { return (DataTypeE); }
@end

@implementation TypeB2DConverter
-(OCDataItemType)inputType { return (DataTypeB); }
-(OCDataItemType)outputType { return (DataTypeD); }
@end

@interface DataSourceTests : XCTestCase

@end

@implementation DataSourceTests

- (void)testDataSourceInitialSnapshotAndBasicMutations
{
	OCDataSource *source = [OCDataSource new];
	OCDataSourceSnapshot *snapshot;

	OCDataSourceSubscription *subscription = [source subscribeWithUpdateHandler:^(OCDataSourceSubscription * _Nonnull subscription) {
		OCLog(@"Subscription notified of update");
	} onQueue:nil trackDifferences:YES performIntialUpdate:NO];

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
	} onQueue:nil trackDifferences:YES performIntialUpdate:NO];

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
	} onQueue:nil trackDifferences:YES performIntialUpdate:NO];

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

- (void)testDataConverterAssembly
{
	OCDataRenderer *renderer = [[OCDataRenderer alloc] initWithConverters:@[
		[[TypeA2BConverter alloc] init],
		[[TypeB2CConverter alloc] init],
		[[TypeC2DConverter alloc] init],
		[[TypeD2EConverter alloc] init],
	]];

	// Assemble viable pipeline

	OCDataConverterPipeline *pipelineAToE;

	pipelineAToE = (OCDataConverterPipeline *)[renderer assembledConverterFrom:DataTypeA to:DataTypeE];

	XCTAssert(pipelineAToE != nil);
	XCTAssert(pipelineAToE.converters.count == 4);
	XCTAssert([pipelineAToE.converters[0] isKindOfClass:TypeA2BConverter.class]);
	XCTAssert([pipelineAToE.converters[1] isKindOfClass:TypeB2CConverter.class]);
	XCTAssert([pipelineAToE.converters[2] isKindOfClass:TypeC2DConverter.class]);
	XCTAssert([pipelineAToE.converters[3] isKindOfClass:TypeD2EConverter.class]);

	OCLogDebug(@"Assembled pipeline from A to E: %@", pipelineAToE.converters);

	// Try to assemble unviable pipeline

	OCDataConverterPipeline *pipelineEToA;

	pipelineEToA = (OCDataConverterPipeline *)[renderer assembledConverterFrom:DataTypeE to:DataTypeA];

	XCTAssert(pipelineEToA == nil);
}

- (void)testDataConverterAssemblyShortestRoute
{
	OCDataRenderer *renderer = [[OCDataRenderer alloc] initWithConverters:@[
		// 4-step route
		[[TypeA2BConverter alloc] init],
		[[TypeB2CConverter alloc] init],
		[[TypeC2DConverter alloc] init],
		[[TypeD2EConverter alloc] init],

		// Shortcut to allow 3-step route
		[[TypeB2DConverter alloc] init],
	]];

	// Assemble 3-4 step pipeline
	OCDataConverterPipeline *pipelineAToE;

	pipelineAToE = (OCDataConverterPipeline *)[renderer assembledConverterFrom:DataTypeA to:DataTypeE];

	XCTAssert(pipelineAToE != nil);
	XCTAssert(pipelineAToE.converters.count == 3);
	XCTAssert([pipelineAToE.converters[0] isKindOfClass:TypeA2BConverter.class]);
	XCTAssert([pipelineAToE.converters[1] isKindOfClass:TypeB2DConverter.class]);
	XCTAssert([pipelineAToE.converters[2] isKindOfClass:TypeD2EConverter.class]);

	OCLogDebug(@"Assembled pipeline from A to E: %@", pipelineAToE.converters);

	// Assemble 2-3 step pipeline
	OCDataConverterPipeline *pipelineAToD;

	pipelineAToD = (OCDataConverterPipeline *)[renderer assembledConverterFrom:DataTypeA to:DataTypeD];

	XCTAssert(pipelineAToD != nil);
	XCTAssert(pipelineAToD.converters.count == 2);
	XCTAssert([pipelineAToD.converters[0] isKindOfClass:TypeA2BConverter.class]);
	XCTAssert([pipelineAToD.converters[1] isKindOfClass:TypeB2DConverter.class]);

	OCLogDebug(@"Assembled pipeline from A to E: %@", pipelineAToD.converters);
}

@end
