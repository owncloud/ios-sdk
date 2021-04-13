//
//  OCCore+ItemPolicies.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 10.07.19.
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
#import "OCItemPolicyProcessor.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, OCCoreItemPolicyOption)
{
	OCCoreItemPolicyOptionNone = 0,
	OCCoreItemPolicyOptionSkipTrigger = 1<<0
};

@interface OCCore (ItemPolicies)

#pragma mark - Administration
- (void)addItemPolicy:(OCItemPolicy *)policy options:(OCCoreItemPolicyOption)options completionHandler:(nullable OCCoreCompletionHandler)completionHandler;
- (void)updateItemPolicy:(OCItemPolicy *)policy options:(OCCoreItemPolicyOption)options completionHandler:(nullable OCCoreCompletionHandler)completionHandler;
- (void)removeItemPolicy:(OCItemPolicy *)policy options:(OCCoreItemPolicyOption)options completionHandler:(nullable OCCoreCompletionHandler)completionHandler;

- (void)addItemPolicyProcessor:(OCItemPolicyProcessor *)processor;
- (void)removeItemPolicyProcessor:(OCItemPolicyProcessor *)processor;

- (nullable OCItemPolicyProcessor *)itemPolicyProcessorForKind:(OCItemPolicyKind)kind;

- (void)retrievePoliciesOfKind:(nullable OCItemPolicyKind)kind affectingItem:(nullable OCItem *)item includeInternal:(BOOL)includeInternal completionHandler:(void(^)(NSError * _Nullable error, NSArray<OCItemPolicy *> * _Nullable policies))completionHandler;

#pragma mark - Policy application
- (void)runProtectedPolicyProcessorsForTrigger:(OCItemPolicyProcessorTrigger)triggerMask;
- (void)runPolicyProcessorsForTrigger:(OCItemPolicyProcessorTrigger)triggerMask;

- (void)runPolicyProcessorsOnNewUpdatedAndDeletedItems:(NSArray <OCItem *> *)items forTrigger:(OCItemPolicyProcessorTrigger)triggerMask;

#pragma mark - Setup & teardown
- (void)setupItemPolicies;
- (void)teardownItemPolicies;

@end

extern OCIPCNotificationName OCIPCNotificationNameItemPoliciesChangedPrefix;
extern NSNotificationName OCCoreItemPoliciesChangedNotification;

extern NSErrorUserInfoKey OCErrorItemPoliciesKey;

NS_ASSUME_NONNULL_END
