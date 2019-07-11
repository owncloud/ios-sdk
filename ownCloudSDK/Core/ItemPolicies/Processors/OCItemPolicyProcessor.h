//
//  OCItemPolicyProcessor.h
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

#import <Foundation/Foundation.h>
#import "OCItemPolicy.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, OCItemPolicyProcessorTrigger)
{
	OCItemPolicyProcessorTriggerItemsChanged = (1<<0),		//!< Triggered whenever items change (f.ex. following sync actions, PROPFINDs, etc.)
	OCItemPolicyProcessorTriggerItemListUpdateCompleted = (1<<1),	//!< Triggered whenever an item list update was completed and the database of cache items is considered consistent with server contents
	OCItemPolicyProcessorTriggerPoliciesChanged = (1<<2),		//!< Triggered whenever an item policy was added, removed or updated

	OCItemPolicyProcessorTriggerAll = NSUIntegerMax
};

@interface OCItemPolicyProcessor : NSObject
{
	OCQueryCondition *_policyCondition;
}

@property(weak) OCCore *core;

@property(strong) OCItemPolicyKind kind; //!< Kind of policies this processor processes

@property(readonly) OCItemPolicyProcessorTrigger triggerMask; //!< Mask of when the processor should be triggered

@property(nullable,strong,nonatomic) NSArray<OCItemPolicy *> *policies;	//!< Policies that serve as basis for the processor (typically all policies with the same OCItemPolicyIdentifier)
@property(nullable,strong,nonatomic) OCQueryCondition *policyCondition;	//!< Query condition combining - with ANY-OF - all the query conditions from the policies. Updated when .policies is set.

@property(nullable,strong,nonatomic) OCQueryCondition *matchCondition;	//!< Query condition matching relevant items that may require the policy processor to perform actions on them
@property(nullable,strong,nonatomic) OCQueryCondition *cleanupCondition;//!< Query condition matching items that may require cleanup by the policy processor

@property(nullable,strong) NSString *localizedName; //!< Localized name of the policy
@property(nullable,strong,nonatomic) OCQueryCondition *customQueryCondition;	//!< Query condition that can be used to present items matched by the policy (typically equals .matchCondition). nil if it shouldn't.

- (instancetype)initWithKind:(OCItemPolicyKind)kind core:(OCCore *)core;

#pragma mark - Policy updates
- (void)updateWithPolicies:(nullable NSArray<OCItemPolicy *> *)policies; //!< Called whenever policies have been updated. The processor is responsible for filtering and using them.

#pragma mark - Match handling
- (void)beginMatchingWithTrigger:(OCItemPolicyProcessorTrigger)trigger;
- (void)performActionOn:(OCItem *)matchingItem withTrigger:(OCItemPolicyProcessorTrigger)trigger;
- (void)endMatchingWithTrigger:(OCItemPolicyProcessorTrigger)trigger;

#pragma mark - Cleanup handling
- (void)beginCleanupWithTrigger:(OCItemPolicyProcessorTrigger)trigger;
- (void)performCleanupOn:(OCItem *)cleanupItem withTrigger:(OCItemPolicyProcessorTrigger)trigger;
- (void)endCleanupWithTrigger:(OCItemPolicyProcessorTrigger)trigger;

#pragma mark - Events
- (void)didPassTrigger:(OCItemPolicyProcessorTrigger)trigger;

#pragma mark - Cleanup polices
- (void)performPoliciesAutoRemoval;

/*
	Ideas for policies:
	- Available Offline
		- Download if: matchCondition && !isLocalCopy && !removed
		- Cleanup if: !matchCondition && isLocalCopy && downloadTrigger==availableOffline && !removed
	- Download expiry
		- No matchCondition
		- Cleanup if: isLocalCopy && downloadTrigger==user && lastUsedDate<oldestKeepDate && !removed
	- BurnAfterReading
		- No matchCondition
		- Cleanup if: matchingPolicies && isLocalCopy + retainer==0 check
		- resurrect OCRetainer (=> with download action integration?!) to allow FP and viewer to retain files affected by BurnAfterReading policy
	- Remove removed
		- No matchCondition
		- Cleanup if: removed
*/

@end

extern NSNotificationName OCCoreItemPolicyProcessorUpdated; //!< Notification sent when an item policy processor was updated. The object is the OCItemPolicyProcessor.

NS_ASSUME_NONNULL_END
