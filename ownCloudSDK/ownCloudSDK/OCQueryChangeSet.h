//
//  OCQueryChangeSet.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCItem.h"

@class OCQueryChangeSet;

typedef NS_ENUM(NSUInteger, OCQueryChangeSetOperation)
{
	OCQueryChangeSetOperationInsert,	//!< Insert item(s)
	OCQueryChangeSetOperationRemove,	//!< Remove item(s)
	OCQueryChangeSetOperationUpdate,	//!< Update item(s)

	OCQueryChangeSetOperationContentSwap	//!< Replace items with that from queryResult
};

typedef void(^OCQueryChangeSetEnumerator)(OCQueryChangeSet *changeSet, OCQueryChangeSetOperation operation, NSArray <OCItem *> *items, NSIndexSet *indexSet);

@interface OCQueryChangeSet : NSObject

@property(assign) BOOL containsChanges;			//!< YES if changeset actually contains changes since the last requested changeset, NO if it contains none.
@property(assign) BOOL contentSwap;			//!< YES if the changeset's queryResult completely replaces previous items, NO if it contains no changes or changes broken into insertion/removal/updates.

@property(strong) NSArray <OCItem *> *queryResult;	//!< Returns an array of OCItems representing the query's latest results after sorting and filtering - at the time the change set was requested.

@property(strong) NSIndexSet *insertedItemsIndexSet; 	//!< Indexes at which items were inserted
@property(strong) NSArray <OCItem *> *insertedItems; 	//!< Inserted items in the order of their insertion indexes

@property(strong) NSIndexSet *removedItemsIndexSet;  	//!< Indexes at which items were removed
@property(strong) NSArray <OCItem *> *removedItems;  	//!< Removed items in the order of their insertion indexes

@property(strong) NSIndexSet *updatedItemsIndexSet;  	//!< Indexes at which items were updated
@property(strong) NSArray <OCItem *> *updatedItems;  	//!< Updated items ordered by their index

- (void)enumerateChangesUsingBlock:(OCQueryChangeSetEnumerator)enumerator; //!< Can be used to enumerate

@end
