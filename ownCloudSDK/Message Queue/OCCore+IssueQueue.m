//
//  OCCore+IssueQueue.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 17.02.20.
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

#import "OCCore+IssueQueue.h"
#import "OCVault.h"
#import "OCMacros.h"
#import "OCProcessManager.h"

@implementation OCCore (IssueQueue)

+ (void)load
{
	// Register classes for key
	[OCKeyValueStore registerClasses:[OCEvent.safeClasses setByAddingObjectsFromArray:@[
		OCIssueQueueRecord.class
	]] forKey:OCKeyValueStoreKeyCoreSyncIssueQueue];
}

#pragma mark - SDK interface
#pragma mark - Central entry point for sync issues
- (void)startIssueQueueObservation
{
	[self.vault.keyValueStore addObserver:^(OCKeyValueStore * _Nonnull store, id  _Nullable owner, OCKeyValueStoreKey  _Nonnull key, NSMutableArray<OCIssueQueueRecord *> * _Nonnull queue) {
		//
	} forKey:OCKeyValueStoreKeyCoreSyncIssueQueue withOwner:self initial:YES];
}

- (void)stopIssueQueueObservation
{
	[self.vault.keyValueStore removeObserverForOwner:self forKey:OCKeyValueStoreKeyCoreSyncIssueQueue];
}

- (void)handleSyncIssue:(OCSyncIssue *)syncIssue
{
	BOOL canHandleSyncIssues = [self.delegate respondsToSelector:@selector(core:handleSyncIssue:)];
	__block BOOL isNewIssue = NO;
	__block BOOL isKnownIssue = NO;

	// Add issue to queue
	[self _performSyncIssue:syncIssue queueOperation:^(NSMutableArray<OCIssueQueueRecord *> * _Nonnull queue, OCIssueQueueRecord * _Nullable existingRecord, BOOL * _Nonnull outDidModify) {
		if (existingRecord != nil)
		{
			// Sync issue has already been enqueued
			isKnownIssue = YES;
		}
		else
		{
			// New sync issue
			OCIssueQueueRecord *record = [OCIssueQueueRecord new];

			record.syncIssue = syncIssue;
			record.originProcess = canHandleSyncIssues ? OCProcessManager.sharedProcessManager.processSession : nil;

			isNewIssue = YES;

			[queue addObject:record];
			*outDidModify = YES;
		}
	}];

	// Notify handler
	if (isNewIssue)
	{
		[self notifyClientOfNewIssues:@[ syncIssue ]];
	}
}

- (void)notifyClientOfNewIssues:(NSArray<OCSyncIssue *> *)syncIssues
{

}

#pragma mark - Client interface
- (void)resolveIssuesInQueueWithError:(NSError *)error beforeDate:(nullable NSDate *)beforeDate
{

}

- (void)didPresentSyncIssue:(OCSyncIssue *)syncIssue
{
	[self _performSyncIssue:syncIssue queueOperation:^(NSMutableArray<OCIssueQueueRecord *> * _Nonnull queue, OCIssueQueueRecord * _Nullable existingRecord, BOOL * _Nonnull outDidModify) {
		if (!existingRecord.presentedToUser)
		{
			existingRecord.presentedToUser = YES;
			*outDidModify = YES;
		}
	}];
}

#pragma mark - Queue operations
- (void)_performSyncIssue:(nullable OCSyncIssue *)syncIssue queueOperation:(void(^)(NSMutableArray<OCIssueQueueRecord *> * _Nonnull queue, OCIssueQueueRecord * _Nullable existingRecord, BOOL * _Nonnull outDidModify))queueOperation
{
	[self.vault.keyValueStore updateObjectForKey:OCKeyValueStoreKeyCoreSyncIssueQueue usingModifier:^(id existingObject, BOOL *outDidModify) {
		NSMutableArray<OCIssueQueueRecord *> *queue = nil;
		OCIssueQueueRecord *existingRecord = nil;

		if ((queue = OCTypedCast(existingObject, NSMutableArray)) == nil)
		{
			queue = [NSMutableArray new];
		}
		else
		{
			for (OCIssueQueueRecord *record in queue)
			{
				if ([record.syncIssue.uuid isEqual:syncIssue.uuid])
				{
					existingRecord = record;
					break;
				}
			}
		}

		queueOperation(queue, existingRecord, outDidModify);

		return (queue);
	}];
}

@end

OCKeyValueStoreKey OCKeyValueStoreKeyCoreSyncIssueQueue = @"syncIssuesQueue";
