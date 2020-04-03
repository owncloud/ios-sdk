//
//  OCCore+Claims.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 29.07.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
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

#import "OCCore+Claims.h"
#import "OCCore+Internal.h"
#import "OCCore+ItemUpdates.h"
#import "OCCore+SyncEngine.h"
#import "OCDeallocAction.h"
#import "NSError+OCError.h"

#import <objc/runtime.h>

@implementation OCCore (Claims)

- (void)mutateItem:(OCItem *)inItem withBlock:(OCItem *(^)(OCItem *inItem, OCSyncAnchor newSyncAnchor, BOOL *outItemModified, NSError **outError))itemMutationBlock pullLatest:(BOOL)pullLatest completionHandler:(nullable OCCoreClaimCompletionHandler)completionHandler
{
	[self beginActivity:@"Mutating item"];

	[self incrementSyncAnchorWithProtectedBlock:^NSError *(OCSyncAnchor previousSyncAnchor, OCSyncAnchor newSyncAnchor) {
		BOOL itemModified = NO;
		NSError *error = nil;
		OCItem *item = inItem;
		OCItem *saveItem = nil;

		if (pullLatest)
		{
			__block OCItem *latestItem = nil;

			[self.database retrieveCacheItemForLocalID:item.localID completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, OCItem *item) {
				latestItem = item;
			}];

			item = latestItem;
		}

		if (item != nil)
		{
			saveItem = itemMutationBlock(item, newSyncAnchor, &itemModified, &error);

			if (itemModified && (saveItem != nil))
			{
				[self performUpdatesForAddedItems:nil removedItems:nil updatedItems:@[saveItem] refreshPaths:nil newSyncAnchor:newSyncAnchor beforeQueryUpdates:nil afterQueryUpdates:nil queryPostProcessor:nil skipDatabase:NO];
			}
		}
		else
		{
			if (error == nil)
			{
				error = OCError(OCErrorItemNotFound);
			}
		}

		if (completionHandler != nil)
		{
			completionHandler(error, item);
		}

		return (nil);
	} completionHandler:^(NSError *error, OCSyncAnchor previousSyncAnchor, OCSyncAnchor newSyncAnchor) {
		[self endActivity:@"Mutating item"];
	}];
}

- (void)addClaim:(OCClaim *)claim onItem:(OCItem *)item completionHandler:(nullable OCCoreClaimCompletionHandler)completionHandler
{
	OCLogDebug(@"Adding claim %@ on %@", claim, OCLogPrivate(item));

	[self mutateItem:item withBlock:^OCItem *(OCItem *inItem, OCSyncAnchor newSyncAnchor, BOOL *outItemModified, NSError *__autoreleasing *outError) {
		inItem.fileClaim = [OCClaim combining:inItem.fileClaim with:claim usingOperator:OCClaimGroupOperatorOR];
		*outItemModified = YES;

		OCLogDebug(@"Added claim %@ on %@", claim, OCLogPrivate(inItem));

		return (inItem);
	} pullLatest:NO completionHandler:completionHandler];
}

- (void)removeClaimWithIdentifier:(OCClaimIdentifier)claimIdentifier onItem:(OCItem *)item refreshItem:(BOOL)refreshItem completionHandler:(nullable OCCoreClaimCompletionHandler)completionHandler
{
	OCLogDebug(@"Removing claim with ID %@ on %@ (refreshItem: %d)", claimIdentifier, OCLogPrivate(item), refreshItem);

	[self mutateItem:item withBlock:^OCItem *(OCItem *inItem, OCSyncAnchor newSyncAnchor, BOOL *outItemModified, NSError *__autoreleasing *outError) {
		inItem.fileClaim = [inItem.fileClaim removingClaimWithIdentifier:claimIdentifier];
		*outItemModified = YES;

		OCLogDebug(@"Removed claim with ID %@ on %@ (refreshItem: %d)", claimIdentifier, OCLogPrivate(inItem), refreshItem);

		return (inItem);
	} pullLatest:refreshItem completionHandler:completionHandler];
}

- (void)removeClaim:(OCClaim *)claim onItem:(OCItem *)item refreshItem:(BOOL)refreshItem completionHandler:(nullable OCCoreClaimCompletionHandler)completionHandler
{
	OCLogDebug(@"(handing off) Removing claim %@ on %@ (refreshItem: %d)", claim, OCLogPrivate(item), refreshItem);

	[self removeClaimWithIdentifier:claim.identifier onItem:item refreshItem:refreshItem completionHandler:completionHandler];
}

- (void)removeClaimsWithExplicitIdentifier:(OCClaimExplicitIdentifier)claimExplicitIdentifier onItem:(OCItem *)item refreshItem:(BOOL)refreshItem completionHandler:(nullable OCCoreClaimCompletionHandler)completionHandler
{
	OCLogDebug(@"Removing claims with explicit identifier %@ on %@ (refreshItem: %d)", claimExplicitIdentifier, OCLogPrivate(item), refreshItem);

	[self mutateItem:item withBlock:^OCItem *(OCItem *inItem, OCSyncAnchor newSyncAnchor, BOOL *outItemModified, NSError *__autoreleasing *outError) {
		inItem.fileClaim = [inItem.fileClaim removingClaimsWithExplicitIdentifier:claimExplicitIdentifier];
		*outItemModified = YES;

		OCLogDebug(@"Removed claims with explicit identifier %@ on %@ (refreshItem: %d)", claimExplicitIdentifier, OCLogPrivate(inItem), refreshItem);

		return (inItem);
	} pullLatest:refreshItem completionHandler:completionHandler];
}

- (OCClaim *)generateTemporaryClaimForPurpose:(OCCoreClaimPurpose)purpose
{
	OCClaim *claim = nil;

	switch (purpose)
	{
		case OCCoreClaimPurposeNone:
		break;

		case OCCoreClaimPurposeView:
			claim = [OCClaim claimForLifetimeOfCore:self explicitIdentifier:nil withLockType:OCClaimLockTypeRead];
		break;
	}

	OCLogDebug(@"Generated temporary claim %@ for purpose %lu", claim, (unsigned long)purpose);

	return (claim);
}

- (void)removeClaim:(OCClaim *)claim onItem:(OCItem *)item afterDeallocationOf:(NSArray *)objects
{
	__weak OCCore *weakCore = self;
	BOOL couldAddClaimRemovalTrigger = NO;
	OCClaimIdentifier claimID = claim.identifier;

	static int DeallocTokenKey;
	const void *DeallocTokenKeyPtr = &DeallocTokenKey;

	OCLogDebug(@"Asked to removing claim %@ on item %@ after deallocation of %@", claim, OCLogPrivate(item), objects);

	@synchronized(claim)
	{
		NSObject *deallocToken = nil; // Actual deallocationToken - strongly referenced by everything in _objects_, claim is removed on deallocation of token

		/*
			Works like this

			_claimTokensByClaimIdentifier
			- NSMapTable tracking claimID : deallocToken reference
			- stores deallocToken weakly referenced and claimID strongly referenced

			deallocToken
			- strongly referenced by all _objects_
			- on deallocation, removes claim with claimID
		*/

		// Set up or retrieve deallocation token
		@synchronized(_claimTokensByClaimIdentifier)
		{
			// Ensure there's only one deallocToken in use per claim (which could come in via different, but identical OCClaim instances)
			if ((deallocToken = [_claimTokensByClaimIdentifier objectForKey:claimID]) == nil)
			{
				deallocToken = [NSObject new];
				[_claimTokensByClaimIdentifier setObject:deallocToken forKey:claimID];

				[OCDeallocAction addAction:^{
					OCLogDebug(@"Removing claim %@ on item %@ after last object was deallocated", claimID, item);

					[weakCore removeClaimWithIdentifier:claimID onItem:item refreshItem:YES completionHandler:nil];
				} forDeallocationOfObject:deallocToken];
			}
		}

		if (deallocToken != nil)
		{
			OCLogDebug(@"Adding %@ to token %p for claim %p", objects, deallocToken, claim);

			for (id object in objects)
			{
				objc_setAssociatedObject(object, DeallocTokenKeyPtr, deallocToken, OBJC_ASSOCIATION_RETAIN);
			}

			couldAddClaimRemovalTrigger = YES;
		}
	}

	OCLogDebug(@"Will be removing claim %@ on item %@ after deallocation of %@: success=%d", claim, OCLogPrivate(item), objects, couldAddClaimRemovalTrigger);
}

@end
