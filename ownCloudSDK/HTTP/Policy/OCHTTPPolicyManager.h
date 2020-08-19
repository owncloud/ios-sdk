//
//  OCHTTPPolicyManager.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.07.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCHTTPPipeline.h"
#import "OCHTTPPolicy.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCHTTPPolicyManager : NSObject

#pragma mark - Shared instance
@property(strong,nonatomic,readonly,class) OCHTTPPolicyManager *sharedManager;

#pragma mark - Global policies (apply to all pipelines and requests)
@property(strong,nonatomic,nullable) NSArray<OCHTTPPolicy *> *preProcessingPolicies;
@property(strong,nonatomic,nullable) NSArray<OCHTTPPolicy *> *postProcessingPolicies;

//#pragma mark - Partition policies
//- (void)setPolicy:(OCHTTPPolicy *)policy forPipelinePartitionID:(OCHTTPPipelinePartitionID)partitionID;
//
//- (void)removePolicyWithIdentifier:(OCHTTPPolicyIdentifier)policyIdentifier forPipelinePartitionID:(OCHTTPPipelinePartitionID)partitionID;
//- (void)removeAllPoliciesForPipelinePartitionID:(OCHTTPPipelinePartitionID)partitionID;
//
//- (nullable NSArray<OCHTTPPolicy *> *)policiesForPipelinePartitionID:(OCHTTPPipelinePartitionID)partitionID;

#pragma mark - Applicable policies
- (nullable NSArray<OCHTTPPolicy *> *)applicablePoliciesForPipelinePartitionID:(OCHTTPPipelinePartitionID)partitionID handler:(nullable id<OCHTTPPipelinePartitionHandler>)handler;

@end

NS_ASSUME_NONNULL_END
