//
//  OCCore+IssueQueue.h
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

#import <Foundation/Foundation.h>
#import "OCCore.h"
#import "OCSyncIssue.h"
#import "OCIssueQueueRecord.h"

/*
	Sync Issue Queue:

	# New Sync Issue:
	1) Sync Engine hands over issues to -handleSyncIssue:
	2) -handleSyncIssue:
		a) checks if the sync issue has already been enqueued
			- if not, enqueues the issue
			- otherwise
		b) checks if the OCCore.delegate implements OCCoreIssueQueueHandlingDelegate - and if it does:
			- adds the sync issue to the queue
			- notifies the OCCoreIssueQueueHandlingDelegate of the new issue
		c) if not, checks if there is an OCCore.delegate:
			- sends the sync issue as OCIssue to the OCCoreDelegate error/issue handling method
			- keeps the core alive until the issue receives a response or the OCIssue's enqueue handler is called
		d) if not, tries to respond to the the issue in a non-destructive way

	# Handling Sync Issue:
	1) 

 */

NS_ASSUME_NONNULL_BEGIN

@protocol OCCoreIssueQueueHandlingDelegate <NSObject>

@optional
- (void)core:(OCCore *)core handleSyncIssue:(OCSyncIssue *)syncIssue;

//- (void)core:(OCCore *)core hasNewSyncIssues:(NSArray <OCSyncIssue *> *)syncIssues;
//- (void)core:(OCCore *)core resolvedSyncIssues:(NSArray <OCSyncIssue *> *)syncIssues;

@end

#pragma mark - SDK interface
@interface OCCore (IssueQueueSDK)

#pragma mark  - Central entry point for sync issues
- (void)handleSyncIssue:(OCSyncIssue *)issue;

@end

#pragma mark - Client interface
@interface OCCore (IssueQueueClient)

- (void)resolveIssuesInQueueWithError:(NSError *)error beforeDate:(nullable NSDate *)beforeDate; //!< Tries to auto-resolve issues older than beforeDate that can be auto-resolved following the resolution of an error

- (void)didPresentSyncIssue:(OCSyncIssue *)syncIssue; //!< Notify the core that the issue has been presented

@end

extern OCKeyValueStoreKey OCKeyValueStoreKeyCoreSyncIssueQueue;

NS_ASSUME_NONNULL_END
