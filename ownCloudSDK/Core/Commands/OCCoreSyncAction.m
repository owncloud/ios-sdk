//
//  OCCoreSyncAction.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.09.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCCoreSyncAction.h"
#import <objc/runtime.h>

@implementation OCCoreSyncAction

#pragma mark - Implementation
- (BOOL)implements:(SEL)featureSelector
{
	IMP rootClassIMP = method_getImplementation(class_getInstanceMethod([OCCoreSyncAction class], featureSelector));
	IMP selfClassIMP = method_getImplementation(class_getInstanceMethod([self class], featureSelector));

	if (rootClassIMP != selfClassIMP)
	{
		return (YES);
	}

	return (NO);
}

#pragma mark - Retrieve existing records (preflight)
- (void)retrieveExistingRecordsForContext:(OCCoreSyncContext *)syncContext
{
	// Retrieve existing records for same action/path combination
	if (syncContext.syncRecord.itemPath != nil)
	{
		[self.core.vault.database retrieveSyncRecordsForPath:syncContext.syncRecord.itemPath action:syncContext.syncRecord.action inProgressSince:nil completionHandler:^(OCDatabase *db, NSError *error, NSArray<OCSyncRecord *> *syncRecords) {
			syncContext.existingRecords = syncRecords;
		}];
	}
}

#pragma mark - Preflight and descheduling
- (void)preflightWithContext:(OCCoreSyncContext *)syncContext
{
}

- (void)descheduleWithContext:(OCCoreSyncContext *)syncContext
{
}

#pragma mark - Scheduling and result handling
- (BOOL)scheduleWithContext:(OCCoreSyncContext *)syncContext
{
	return (YES);
}

- (BOOL)handleResultWithContext:(OCCoreSyncContext *)syncContext
{
	return (YES);
}

@end
