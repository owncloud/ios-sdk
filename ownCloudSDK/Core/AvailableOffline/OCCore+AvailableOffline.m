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

@implementation OCCore (AvailableOffline)

- (void)makeAvailableOffline:(OCItem *)item options:(nullable NSDictionary <OCCoreOption, id> *)options completionHandler:(nullable OCCoreItemPolicyCompletionHandler)completionHandler
{
	if (OCTypedCast(options[OCCoreOptionSkipRedundancyChecks], NSNumber).boolValue)
	{
		// Skip redundancy checks
		OCItemPolicy *newItemPolicy;

		if ((newItemPolicy = [[OCItemPolicy alloc] initWithKind:OCItemPolicyKindAvailableOffline item:item]) != nil)
		{
			newItemPolicy.path = item.path;
			newItemPolicy.localID = item.localID;

			newItemPolicy.policyAutoRemovalMethod = OCItemPolicyAutoRemovalMethodNoItems;
 			newItemPolicy.policyAutoRemovalCondition = [OCQueryCondition require:@[
 				[OCQueryCondition where:OCItemPropertyNameRemoved isEqualTo:@(NO)],
 				(item.type == OCItemTypeFile) ?
 					newItemPolicy.condition : // File condition == policy.condition
 					[OCQueryCondition where:OCItemPropertyNamePath isEqualTo:item.path] // Folder condition == exact path match
 			]];

			// Add item policy
			[self addItemPolicy:newItemPolicy completionHandler:^(NSError * _Nullable error) {
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

				if ((newItemPolicy = [[OCItemPolicy alloc] initWithKind:OCItemPolicyKindAvailableOffline item:item]) != nil)
				{
					OCCore *core = self;

					// Add item policy
					[self addItemPolicy:newItemPolicy completionHandler:^(NSError * _Nullable error) {
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
	[self removeItemPolicy:itemPolicy completionHandler:completionHandler];
}

@end
