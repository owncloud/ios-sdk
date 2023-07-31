//
//  OCQueryChangeSet.h
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
#import "OCItem.h"

@class OCQueryChangeSet;

typedef NS_ENUM(NSUInteger, OCQueryChangeSetOperation)
{
	OCQueryChangeSetOperationInsert,	//!< Insert item(s)
	OCQueryChangeSetOperationRemove,	//!< Remove item(s)
	OCQueryChangeSetOperationUpdate,	//!< Update item(s)

	OCQueryChangeSetOperationContentSwap	//!< Replace items with that from queryResult
};

NS_ASSUME_NONNULL_BEGIN

typedef void(^OCQueryChangeSetEnumerator)(OCQueryChangeSet *changeSet, OCQueryChangeSetOperation operation, NSArray <OCItem *> * _Nullable items, NSIndexSet * _Nullable indexSet);

@interface OCQueryChangeSet : NSObject

@property(assign) BOOL containsChanges;			//!< YES if changeset actually contains changes since the last requested changeset, NO if it contains none.
@property(assign) BOOL contentSwap;			//!< YES if the changeset's queryResult completely replaces previous items, NO if it contains no changes or changes broken into insertion/removal/updates.

@property(strong,nullable) NSArray <OCItem *> *queryResult;	//!< Returns an array of OCItems representing the query's latest results after sorting and filtering - at the time the change set was requested.

@property(strong,nullable) NSIndexSet *insertedItemsIndexSet; 	//!< Indexes at which items were inserted
@property(strong,nullable) NSArray <OCItem *> *insertedItems; 	//!< Inserted items ordered by index

@property(strong,nullable) NSIndexSet *removedItemsIndexSet;  	//!< Indexes at which items were removed
@property(strong,nullable) NSArray <OCItem *> *removedItems;  	//!< Removed items ordered by index

@property(strong,nullable) NSIndexSet *updatedItemsIndexSet;  	//!< Indexes at which items were updated
@property(strong,nullable) NSArray <OCItem *> *updatedItems;  	//!< Updated items ordered by index

@property(strong,nullable) OCSyncAnchor syncAnchor;		//!< For sync anchor queries, the sync anchor at the time of the changeset

#pragma mark - Init & Dealloc
- (instancetype)initWithQueryResult:(NSArray <OCItem *> *)queryResult relativeTo:(nullable NSArray <OCItem *> *)previousQueryResult;

#pragma mark - Change set enumeration
- (void)enumerateChangesUsingBlock:(OCQueryChangeSetEnumerator)enumerator; //!< Can be used to enumerate

@end

NS_ASSUME_NONNULL_END
