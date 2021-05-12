//
//  OCItemPolicyProcessor.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 12.07.19.
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

#import "OCItemPolicyProcessor.h"
#import "OCMacros.h"
#import "OCCore.h"
#import "OCCore+ItemPolicies.h"
#import "OCLogger.h"

@implementation OCItemPolicyProcessor

- (instancetype)initWithKind:(OCItemPolicyKind)kind core:(OCCore *)core
{
	if ((self = [super init]) != nil)
	{
		_kind = kind;
		_core = core;
	}

	return (self);
}

#pragma mark - Trigger
- (OCItemPolicyProcessorTrigger)triggerMask
{
	return (OCItemPolicyProcessorTriggerItemListUpdateCompleted);
}

#pragma mark - Policy updates
- (void)updateWithPolicies:(nullable NSArray<OCItemPolicy *> *)policies
{
	NSArray<OCItemPolicy *> *applicablePolicies = nil;

	applicablePolicies = [policies filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(OCItemPolicy *policy, NSDictionary<NSString *,id> * _Nullable bindings) {
		return ([policy.kind isEqualToString:self.kind]);
	}]];

	if (applicablePolicies.count == 0) { applicablePolicies = nil; }

	self.policies = applicablePolicies;

	[[NSNotificationCenter defaultCenter] postNotificationName:OCCoreItemPolicyProcessorUpdated object:self];
}

- (void)performPreflightOnPoliciesWithTrigger:(OCItemPolicyProcessorTrigger)trigger withItems:(nullable NSArray<OCItem *> *)newUpdatedAndRemovedItems
{
	
}

- (void)setPolicies:(NSArray<OCItemPolicy *> *)policies
{
	@synchronized(self)
	{
		NSMutableArray<OCQueryCondition *> *policyConditions = [NSMutableArray new];

		_policies = policies;

		for (OCItemPolicy *policy in policies)
		{
			if (policy.condition != nil)
			{
				[policyConditions addObject:policy.condition];
			}
		}

		self.policyCondition = (policyConditions.count == 0) ? nil : [OCQueryCondition anyOf:policyConditions];
	}
}

#pragma mark - Match handling
- (void)beginMatchingWithTrigger:(OCItemPolicyProcessorTrigger)trigger
{
}

- (void)performActionOn:(OCItem *)matchingItem withTrigger:(OCItemPolicyProcessorTrigger)trigger
{
}

- (void)endMatchingWithTrigger:(OCItemPolicyProcessorTrigger)trigger
{
}

#pragma mark - Cleanup handling
- (void)beginCleanupWithTrigger:(OCItemPolicyProcessorTrigger)trigger
{
}

- (void)performCleanupOn:(OCItem *)cleanupItem withTrigger:(OCItemPolicyProcessorTrigger)trigger
{
}

- (void)endCleanupWithTrigger:(OCItemPolicyProcessorTrigger)trigger
{
}

#pragma mark - Events
- (void)willEnterTrigger:(OCItemPolicyProcessorTrigger)trigger
{

}

- (void)didPassTrigger:(OCItemPolicyProcessorTrigger)trigger
{

}

#pragma mark - Cleanup polices
- (void)performPoliciesAutoRemoval
{
	NSMutableArray<OCItemPolicy *> *removeItemPolicies = nil;

	@synchronized(self)
	{
		for (OCItemPolicy *policy in _policies)
		{
			__block BOOL removePolicy = NO;

			switch (policy.policyAutoRemovalMethod)
			{
				case OCItemPolicyAutoRemovalMethodNone:
				break;

				case OCItemPolicyAutoRemovalMethodNoItems: {
					OCQueryCondition *autoRemovalCondition;

					if ((autoRemovalCondition = policy.policyAutoRemovalCondition) != nil)
					{
						OCSyncExec(retrieveCacheItems, {
							[self.core.vault.database retrieveCacheItemsForQueryCondition:autoRemovalCondition cancelAction:nil completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, NSArray<OCItem *> *items) {
								if (items.count == 0)
								{
									removePolicy = YES;
								}

								OCSyncExecDone(retrieveCacheItems);
							}];
						});
					}
				}
				break;
			}

			if (removePolicy)
			{
				OCItemPolicy *updatedItemPolicy;

				if ((updatedItemPolicy = [self attemptRecoveryOfPolicy:policy]) != nil)
				{
					if (updatedItemPolicy.databaseID != nil)
					{
						[self.core updateItemPolicy:updatedItemPolicy options:OCCoreItemPolicyOptionSkipTrigger completionHandler:nil];
						removePolicy = NO;
					}
					else
					{
						[self.core addItemPolicy:updatedItemPolicy options:OCCoreItemPolicyOptionSkipTrigger completionHandler:nil];
					}
				}
			}

			if (removePolicy)
			{
				if (removeItemPolicies == nil)
				{
					removeItemPolicies = [[NSMutableArray alloc] initWithObjects:policy, nil];
				}
				else
				{
					[removeItemPolicies addObject:policy];
				}
			}
		}

	}

	for (OCItemPolicy *removePolicy in removeItemPolicies)
	{
		[self.core removeItemPolicy:removePolicy options:OCCoreItemPolicyOptionSkipTrigger completionHandler:nil];
	}
}

- (nullable OCItemPolicy *)attemptRecoveryOfPolicy:(OCItemPolicy *)itemPolicy
{
	return (nil);
}

#pragma mark - Class settings
+ (OCClassSettingsIdentifier)classSettingsIdentifier
{
	return (OCClassSettingsIdentifierItemPolicy);
}

+ (nullable NSDictionary<OCClassSettingsKey, id> *)defaultSettingsForIdentifier:(OCClassSettingsIdentifier)identifier
{
	return (@{});
}

@end

NSNotificationName OCCoreItemPolicyProcessorUpdated = @"org.owncloud.item-policy-processor-update";

OCClassSettingsIdentifier OCClassSettingsIdentifierItemPolicy = @"item-policy";
