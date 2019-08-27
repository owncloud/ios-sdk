//
//  OCCore+AvailableOffline.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 08.07.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCCore.h"
#import "OCCore+ItemPolicies.h"
#import "OCItemPolicy.h"
#import "NSError+OCError.h"
#import "OCMacros.h"
#import "OCItemPolicyProcessorAvailableOffline.h"
#import "OCCore+SyncEngine.h"
#import "OCCore+Internal.h"
#import "OCLogger.h"
#import "OCCore+ItemUpdates.h"

@implementation OCCore (AvailableOffline)

- (OCItemPolicy *)_createAvailableOfflinePolicyForItem:(OCItem *)item
{
	OCItemPolicy *newItemPolicy;

	if ((newItemPolicy = [[OCItemPolicy alloc] initWithKind:OCItemPolicyKindAvailableOffline item:item]) != nil)
	{
		newItemPolicy.path = item.path;
		newItemPolicy.localID = item.localID;

		newItemPolicy.policyAutoRemovalMethod = OCItemPolicyAutoRemovalMethodNoItems;
		newItemPolicy.policyAutoRemovalCondition = [OCQueryCondition require:@[
			[OCQueryCondition where:OCItemPropertyNameRemoved isEqualTo:@(NO)],
			[OCQueryCondition where:OCItemPropertyNameLocalID isEqualTo:item.localID]
		]];
	}

	return (newItemPolicy);
}

- (void)makeAvailableOffline:(OCItem *)item options:(nullable NSDictionary <OCCoreOption, id> *)options completionHandler:(nullable OCCoreItemPolicyCompletionHandler)completionHandler
{
	if (item == nil)
	{
		OCLogError(@"Can't make nil item available offline");

		if (completionHandler != nil)
		{
			completionHandler(OCError(OCErrorInsufficientParameters), nil);
		}
		return;
	}

	if (OCTypedCast(options[OCCoreOptionConvertExistingLocalDownloads], NSNumber).boolValue)
	{
		// Convert existing local downloads to ones managed by available offline
		completionHandler = ^(NSError * _Nullable error, OCItemPolicy * _Nullable itemPolicy) {
			if ((error == nil) && (itemPolicy != nil))
			{
				[self beginActivity:@"Convert existing local copies"];

				[self performProtectedSyncBlock:^NSError *{
					NSMutableArray<OCItem *> *updateItems = [NSMutableArray new];

					[self.vault.database iterateCacheItemsForQueryCondition:[OCQueryCondition require:@[
						[OCQueryCondition where:OCItemPropertyNameRemoved isEqualTo:@(NO)], // not removed
						[OCQueryCondition where:OCItemPropertyNameCloudStatus isEqualTo:@(OCItemCloudStatusLocalCopy)], // local copy
						[OCQueryCondition where:OCItemPropertyNameType isEqualTo:@(OCItemTypeFile)], // file
						[OCQueryCondition where:OCItemPropertyNameDownloadTrigger isNotEqualTo:OCItemDownloadTriggerIDAvailableOffline], // not already marked as available offline
						itemPolicy.condition
					]] excludeRemoved:NO withIterator:^(NSError *error, OCSyncAnchor syncAnchor, OCItem *item, BOOL *stop) {
						if (item != nil)
						{
							if (item.activeSyncRecordIDs.count == 0)
							{
								item.downloadTriggerIdentifier = OCItemDownloadTriggerIDAvailableOffline;
							}
							[updateItems addObject:item];
						}
						else
						{
							if (updateItems.count > 0)
							{
								[self performUpdatesForAddedItems:nil removedItems:nil updatedItems:updateItems refreshPaths:nil newSyncAnchor:nil beforeQueryUpdates:nil afterQueryUpdates:nil queryPostProcessor:nil skipDatabase:NO];
							}
						}
					}];

					return (nil);
				} completionHandler:^(NSError *error) {
					[self endActivity:@"Convert existing local copies"];
				}];
			}

			if (completionHandler != nil)
			{
				completionHandler(error, itemPolicy);
			}
		};
	}

	if (OCTypedCast(options[OCCoreOptionSkipRedundancyChecks], NSNumber).boolValue)
	{
		// Skip redundancy checks
		OCItemPolicy *newItemPolicy;

		if ((newItemPolicy = [self _createAvailableOfflinePolicyForItem:item]) != nil)
		{
			// Add item policy
			[self addItemPolicy:newItemPolicy options:OCCoreItemPolicyOptionNone completionHandler:^(NSError * _Nullable error) {
				if (completionHandler != nil)
				{
					completionHandler(error, (error == nil) ? newItemPolicy : nil);
				}
			}];
		}
	}
	else
	{
		// Check for existing available offline policy covering item
		[self retrieveAvailableOfflinePoliciesCoveringItem:item completionHandler:^(NSError * _Nullable error, NSArray <OCItemPolicy *> * _Nullable itemPolicies) {
			if ((itemPolicies==nil) || (itemPolicies.count == 0))
			{
				// Item not yet covered
				OCItemPolicy *newItemPolicy;

				if ((newItemPolicy = [self _createAvailableOfflinePolicyForItem:item]) != nil)
				{
					OCCore *core = self;

					// Add item policy
					[self addItemPolicy:newItemPolicy options:OCCoreItemPolicyOptionNone completionHandler:^(NSError * _Nullable error) {
						// Item policy added
						if (error != nil)
						{
							// An error occured => return
							if (completionHandler != nil)
							{
								completionHandler(error, nil);
							}
						}
						else
						{
							// No error => check for newly redundant item policies
							[core retrievePoliciesOfKind:OCItemPolicyKindAvailableOffline affectingItem:nil includeInternal:NO completionHandler:^(NSError * _Nullable error, NSArray<OCItemPolicy *> * _Nullable allPolicies) {
								NSArray<OCItemPolicy *> *redundantPolicies = [allPolicies filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(OCItemPolicy * _Nullable existingPolicy, NSDictionary<NSString *,id> * _Nullable bindings) {
									return ( (![newItemPolicy.databaseID isEqual:existingPolicy.databaseID]) && // Skip new entry :-D
										 ((existingPolicy.path != nil) && (newItemPolicy.path != nil) && ([existingPolicy.path hasPrefix:newItemPolicy.path])) // Both have paths and existing policy's path is identical or a sub-path of new path
									       );
								}]];

								if (completionHandler != nil)
								{
									NSString *errorMessage = nil;

									if (redundantPolicies.count == 1)
									{
										errorMessage = [NSString stringWithFormat:OCLocalized(@"Making %@ available offline also covers %@, which was previously requested as being available offline."), item.path, itemPolicies.firstObject.path];
									}
									else if (redundantPolicies.count > 1)
									{
										errorMessage = [NSString stringWithFormat:OCLocalized(@"Making %@ available offline also covers %@, whose offline availability has previously been requested."), item.path, [itemPolicies componentsJoinedByString:@", "]];
									}

									completionHandler((redundantPolicies.count > 0) ?
												OCErrorWithDescriptionAndUserInfo(
													OCErrorItemPolicyMakesRedundant,
													errorMessage,
													OCErrorItemPoliciesKey, redundantPolicies
												) :
												nil,
											  newItemPolicy);
								}
							}];
						}
					}];
				}
				else
				{
					// Can't create item policy object => return internal error
					if (completionHandler != nil)
					{
						completionHandler(OCError(OCErrorInternal), nil);
					}
				}
			}
			else
			{
				// Already covered by other item policy
				if (completionHandler != nil)
				{
					completionHandler(OCErrorWithDescriptionAndUserInfo(
								OCErrorItemPolicyRedundant,
								([NSString stringWithFormat:OCLocalized(@"Offline availability of %@ is already ensured by having made %@ available offline."), item.path, itemPolicies.firstObject.path]),
								OCErrorItemPoliciesKey,
								itemPolicies),
							  nil);
				}
			}
		}];
	}
}

- (nullable NSArray <OCItemPolicy *> *)retrieveAvailableOfflinePoliciesCoveringItem:(nullable OCItem *)item completionHandler:(OCCoreItemPoliciesCompletionHandler)completionHandler
{
	__block NSArray <OCItemPolicy *> *relevantItemPolicies = nil;

	if (completionHandler != nil)
	{
		[self retrievePoliciesOfKind:OCItemPolicyKindAvailableOffline affectingItem:item includeInternal:NO completionHandler:^(NSError * _Nullable error, NSArray<OCItemPolicy *> * _Nullable policies) {
			completionHandler(error, policies);
		}];
	}
	else
	{
		OCSyncExec(retrieveItemPolicies, {
			[self retrievePoliciesOfKind:OCItemPolicyKindAvailableOffline affectingItem:item includeInternal:NO completionHandler:^(NSError * _Nullable error, NSArray<OCItemPolicy *> * _Nullable policies) {
				if (error == nil)
				{
					relevantItemPolicies = policies;
				}

				OCSyncExecDone(retrieveItemPolicies);
			}];
		});
	}

	return (relevantItemPolicies);
}

- (void)removeAvailableOfflinePolicy:(OCItemPolicy *)itemPolicy completionHandler:(nullable OCCoreCompletionHandler)completionHandler
{
	[self removeItemPolicy:itemPolicy options:OCCoreItemPolicyOptionNone completionHandler:completionHandler];
}

- (void)_updateAvailableOfflineCaches
{
	if (!_availableOfflineCacheValid)
	{
		NSArray <OCItemPolicy *> *availableOfflinePolicies = [self retrieveAvailableOfflinePoliciesCoveringItem:nil completionHandler:nil];

		[_availableOfflineFolderPaths removeAllObjects];
		[_availableOfflineIDs removeAllObjects];

		for (OCItemPolicy *policy in availableOfflinePolicies)
		{
			if (policy.path != nil)
			{
				[_availableOfflineFolderPaths addObject:policy.path];
			}

			if (policy.localID != nil)
			{
				[_availableOfflineIDs addObject:policy.localID];
			}
		}

		_availableOfflineCacheValid = YES;
	}
}

- (OCCoreAvailableOfflineCoverage)availableOfflinePolicyCoverageOfItem:(OCItem *)item
{
	OCCoreAvailableOfflineCoverage coverage = OCCoreAvailableOfflineCoverageNone;

	@synchronized(_availableOfflineFolderPaths)
	{
		[self _updateAvailableOfflineCaches];

		if ((item.localID!=nil) && [_availableOfflineIDs containsObject:item.localID])
		{
			coverage = OCCoreAvailableOfflineCoverageDirect;
		}
		else
		{
			OCPath itemPath;

			if ((itemPath = item.path) != nil)
			{
				for (OCPath folderPath in _availableOfflineFolderPaths)
				{
					if ([folderPath isEqualToString:itemPath])
					{
						coverage = OCCoreAvailableOfflineCoverageDirect;
						break;
					}
					else if ([itemPath hasPrefix:folderPath])
					{
						coverage = OCCoreAvailableOfflineCoverageIndirect;
					}
				}
			}
		}
	}

	return (coverage);
}

@end
