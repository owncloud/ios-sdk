//
//  OCHTTPPolicyManager.m
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

#import "OCHTTPPolicyManager.h"
#import "OCHTTPPolicyBookmark.h"
#import "OCKeyValueStore.h"
#import "OCVault.h"
#import "OCLogger.h"
#import "OCLogTag.h"
#import "OCBookmarkManager.h"
#import "OCConnection.h"

static OCKeyValueStoreIdentifier OCKeyValueStoreIdentifierPolicyManagerDatabase = @"http-policy-database";

static OCKeyValueStoreKey OCKeyValueStoreKeyGlobalPreprocessingPolicies = @"global.pre-processing-policies";
static OCKeyValueStoreKey OCKeyValueStoreKeyGlobalPostprocessingPolicies = @"global.post-processing-polcies";
//static OCKeyValueStoreKey OCKeyValueStoreKeyLocalPrefix = @"local.";

@interface OCHTTPPolicyManager ()
{
	OCKeyValueStore *_store;
}
@end

@implementation OCHTTPPolicyManager

#pragma mark - Shared instance
+ (OCHTTPPolicyManager *)sharedManager
{
	static OCHTTPPolicyManager *sharedManager;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedManager = [OCHTTPPolicyManager new];
	});

	return (sharedManager);
}

- (NSURL *)storeURL
{
	return ([OCVault.httpPipelineRootURL URLByAppendingPathComponent:@"httpPolicies" isDirectory:NO]);
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		NSError *error = nil;

		if ([NSFileManager.defaultManager createDirectoryAtURL:self.storeURL.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:@{ NSFileProtectionKey : NSFileProtectionCompleteUntilFirstUserAuthentication } error:&error])
		{
			_store = [[OCKeyValueStore alloc] initWithURL:self.storeURL identifier:OCKeyValueStoreIdentifierPolicyManagerDatabase];
			[_store registerClasses:OCEvent.safeClasses forKey:OCKeyValueStoreKeyGlobalPreprocessingPolicies];
			[_store registerClasses:OCEvent.safeClasses forKey:OCKeyValueStoreKeyGlobalPostprocessingPolicies];
		}
		else
		{
			OCLogError(@"Error creating parent folder for OCHTTPPolicyManager KVS at %@: %@", self.storeURL.URLByDeletingLastPathComponent, error);
		}
	}

	return (self);
}

#pragma mark - Global policies (apply to all pipelines and requests)
- (NSArray<OCHTTPPolicy *> *)preProcessingPolicies
{
	return ([_store readObjectForKey:OCKeyValueStoreKeyGlobalPreprocessingPolicies]);
}

- (void)setPreProcessingPolicies:(NSArray<OCHTTPPolicy *> *)preProcessingPolicies
{
	[_store storeObject:preProcessingPolicies forKey:OCKeyValueStoreKeyGlobalPreprocessingPolicies];
}

- (NSArray<OCHTTPPolicy *> *)postProcessingPolicies
{
	return ([_store readObjectForKey:OCKeyValueStoreKeyGlobalPostprocessingPolicies]);
}

- (void)setPostProcessingPolicies:(NSArray<OCHTTPPolicy *> *)postProcessingPolicies
{
	[_store storeObject:postProcessingPolicies forKey:OCKeyValueStoreKeyGlobalPostprocessingPolicies];
}

//#pragma mark - Partition policies
//- (OCKeyValueStoreKey)_keyForPartitionID:(OCHTTPPipelinePartitionID)partitionID
//{
//	OCKeyValueStoreKey key = [OCKeyValueStoreKeyLocalPrefix stringByAppendingString:partitionID];
//
//	if ([_store registeredClassesForKey:key] == nil)
//	{
//		[_store registerClasses:OCEvent.safeClasses forKey:key];
//	}
//
//	return (key);
//}
//
//- (void)setPolicy:(OCHTTPPolicy *)policy forPipelinePartitionID:(OCHTTPPipelinePartitionID)partitionID
//{
//	[_store updateObjectForKey:[self _keyForPartitionID:partitionID] usingModifier:^id _Nullable(NSMutableArray<OCHTTPPolicy *> * _Nullable existingPolicies, BOOL * _Nonnull outDidModify) {
//		NSMutableArray<OCHTTPPolicy *> *policies = existingPolicies;
//		OCHTTPPolicy *replacePolicy = nil;
//		if (policies == nil) { policies = [NSMutableArray new]; }
//
//		for (OCHTTPPolicy *existingPolicy in existingPolicies)
//		{
//			if ([existingPolicy.identifier isEqual:policy.identifier])
//			{
//				replacePolicy = existingPolicy;
//				break;
//			}
//		}
//
//		if (replacePolicy != nil)
//		{
//			[policies removeObjectIdenticalTo:replacePolicy];
//		}
//
//		[policies addObject:policy];
//		*outDidModify = YES;
//
//		return (policies);
//	}];
//}
//
//- (void)removePolicyWithIdentifier:(OCHTTPPolicyIdentifier)policyIdentifier forPipelinePartitionID:(OCHTTPPipelinePartitionID)partitionID
//{
//	[_store updateObjectForKey:[self _keyForPartitionID:partitionID] usingModifier:^id _Nullable(NSMutableArray<OCHTTPPolicy *> * _Nullable policies, BOOL * _Nonnull outDidModify) {
//		OCHTTPPolicy *removePolicy = nil;
//
//		for (OCHTTPPolicy *policy in policies)
//		{
//			if ([policy.identifier isEqual:policyIdentifier])
//			{
//				removePolicy = policy;
//				break;
//			}
//		}
//
//		if (removePolicy != nil)
//		{
//			[policies removeObjectIdenticalTo:removePolicy];
//			*outDidModify = YES;
//		}
//
//		return (policies);
//	}];
//}
//
//- (void)removeAllPoliciesForPipelinePartitionID:(OCHTTPPipelinePartitionID)partitionID
//{
//	[_store storeObject:nil forKey:[self _keyForPartitionID:partitionID]];
//}
//
//- (nullable NSArray<OCHTTPPolicy *> *)policiesForPipelinePartitionID:(OCHTTPPipelinePartitionID)partitionID
//{
//	return ([_store readObjectForKey:[self _keyForPartitionID:partitionID]]);
//}

#pragma mark - Applicable policies
- (nullable NSArray<OCHTTPPolicy *> *)applicablePoliciesForPipelinePartitionID:(OCHTTPPipelinePartitionID)partitionID handler:(nullable id<OCHTTPPipelinePartitionHandler>)handler
{
	NSArray<OCHTTPPolicy *> *prePolicies=nil, *policies=nil, *postPolicies=nil;
	NSMutableArray <OCHTTPPolicy *> *applicablePolicies=nil;

	if ((prePolicies = self.preProcessingPolicies) != nil)
	{
		applicablePolicies = [[NSMutableArray alloc] initWithArray:prePolicies];
	}

	// Hard-coded OCHTTPPolicyBookmark for (ephermal) connections and saved bookmarks
	// (saving and retrieving a policy for every bookmark could potentially clutter the store with entries for ephermal
	// connections whose bookmarks are never used again… something to find a nice solution for in the future)
	if ((handler != nil) && [handler isKindOfClass:OCConnection.class])
	{
		policies = @[
			[[OCHTTPPolicyBookmark alloc] initWithConnection:(OCConnection *)handler]
		];
	}
	else if (partitionID != nil)
	{
		OCBookmark *savedBookmark = [OCBookmarkManager.sharedBookmarkManager bookmarkForUUID:[[NSUUID alloc] initWithUUIDString:partitionID]];

		if (savedBookmark != nil)
		{
			policies = @[
				[[OCHTTPPolicyBookmark alloc] initWithBookmark:savedBookmark]
			];
		}
	}

	// if ((policies = [self policiesForPipelinePartitionID:partitionID]) != nil)
	if (policies != nil)
	{
		if (applicablePolicies == nil)
		{
			applicablePolicies = [[NSMutableArray alloc] initWithArray:policies];
		}
		else
		{
			[applicablePolicies addObjectsFromArray:policies];
		}
	}

	if ((postPolicies = self.postProcessingPolicies) != nil)
	{
		if (applicablePolicies == nil)
		{
			applicablePolicies = (NSMutableArray <OCHTTPPolicy *> *)postPolicies;
		}
		else
		{
			[applicablePolicies addObjectsFromArray:postPolicies];
		}
	}

	return (applicablePolicies);
}

@end
