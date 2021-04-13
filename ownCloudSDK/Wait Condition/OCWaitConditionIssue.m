//
//  OCWaitConditionIssue.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.01.19.
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

#import "OCWaitConditionIssue.h"
#import "OCProcessManager.h"
#import "OCCore.h"
#import "OCCore+SyncEngine.h"
#import "NSError+OCError.h"
#import "OCIssue+SyncIssue.h"
#import "OCCore+Internal.h"
#import "OCEvent.h"
#import "OCSyncContext.h"
#import "OCSyncRecord.h"
#import "OCSyncAction.h"
#import "OCSyncIssue.h"
#import "OCMessageQueue.h"
#import "OCMessage.h"

@implementation OCWaitConditionIssue

+ (instancetype)waitForIssueResolution:(OCSyncIssue *)issue
{
	OCWaitConditionIssue *waitCondition = [self new];

	waitCondition.issue = issue;

	return (waitCondition);
}

- (void)evaluateWithOptions:(OCWaitConditionOptions)options completionHandler:(OCWaitConditionEvaluationResultHandler)completionHandler
{
	BOOL promptUser = NO;

	if (completionHandler == nil) { return; }

	// Check if issue is resolved
	if (_resolved)
	{
		completionHandler(OCWaitConditionStateProceed, NO, nil);
		return;
	}

	// Check if user should be prompted
	if (_processSession==nil)
	{
		// User has never been prompted
		promptUser = YES;
	}
	else if (![[OCProcessManager sharedProcessManager] isSessionValid:_processSession usingThoroughChecks:YES])
	{
		// Process no longer valid
		promptUser = YES;
	}

	if (promptUser)
	{
		OCCore *core = nil;
		OCSyncRecord *syncRecord = nil;

		if (((core = options[OCWaitConditionOptionCore]) != nil) &&
		    ((syncRecord = options[OCWaitConditionOptionSyncRecord]) != nil)
		   )
		{
			NSDictionary *userInfo = @{
				OCEventUserInfoKeySyncRecordID : syncRecord.recordID,
				OCEventUserInfoKeyWaitConditionUUID : self.uuid
			};

			if (_issue.routingInfo == nil)
			{
				_issue.routingInfo = userInfo;
			}

 			// Update processSession to current
 			_processSession = [OCProcessManager sharedProcessManager].processSession;

			// Allow delegate to directly handle
			BOOL submitToQueue = YES;

			if ([core.delegate respondsToSelector:@selector(core:handleSyncIssue:)])
			{
				submitToQueue = [core.delegate core:core handleSyncIssue:_issue];
			}

			// Submit to queue
			if (submitToQueue)
			{
				[core.messageQueue enqueue:[[OCMessage alloc] initWithSyncIssue:_issue fromCore:core]];
			}
		}
		else
		{
			// Fail
			completionHandler(OCWaitConditionStateFail, NO, OCError(OCErrorFeatureNotImplemented));
			return;
		}
	}

	// Condition not yet met => continue to wait
	completionHandler(OCWaitConditionStateWait, promptUser, nil);
}

#pragma mark - Event handling
- (BOOL)handleEvent:(OCEvent *)event withOptions:(OCWaitConditionOptions)options sender:(id)sender
{
	if (event.eventType == OCEventTypeIssueResponse)
	{
		OCSyncRecord *syncRecord = nil;
		OCSyncContext *syncContext = nil;
		OCSyncIssue *syncIssue = event.userInfo[OCEventUserInfoKeySyncIssue];
		OCSyncIssueChoice *syncIssueChoice = event.result;

		// Ensure this is about the issue handled by this wait condition
		if (!((syncIssue != nil) && (syncIssueChoice!=nil) && ([syncIssue.uuid isEqual:_issue.uuid])))
		{
			return (NO);
		}

		if ( (options[OCWaitConditionOptionCore] != nil) &&
		    ((syncRecord = options[OCWaitConditionOptionSyncRecord]) != nil) &&
		    ((syncContext = options[OCWaitConditionOptionSyncContext]) != nil)
		   )
		{
			NSError *resolutionError = nil;

			resolutionError = [syncRecord.action resolveIssue:_issue withChoice:syncIssueChoice context:syncContext];

			if (resolutionError == nil)
			{
				[syncRecord removeWaitCondition:self];

				if (syncRecord.recordID != nil) // Check if the sync record has been removed as part of the issue resolution (f.ex. when descheduling)
				{
					syncContext.updateStoredSyncRecordAfterItemUpdates = YES;
				}
			}
			else
			{
				// Issue resolution failed, mark sync record as failed
				OCLogError(@"syncAction=%@ could not resolve issue=%@ with choice=%@ due to error=%@. Marking as failed syncRecord=%@", syncRecord.action, syncIssue, syncIssueChoice, resolutionError, syncRecord);

				[syncContext transitionToState:OCSyncRecordStateFailed withWaitConditions:nil];
			}
		}

		return (YES);
	}

	return ([super handleEvent:event withOptions:options sender:sender]);
}

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder
{
	[super encodeWithCoder:coder];

	[coder encodeObject:_issue forKey:@"issue"];
	[coder encodeObject:_processSession forKey:@"processSession"];
	[coder encodeBool:_resolved forKey:@"resolved"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)decoder
{
	if ((self = [super initWithCoder:decoder]) != nil)
	{
		_issue = [decoder decodeObjectOfClass:OCSyncIssue.class forKey:@"issue"];
		_processSession = [decoder decodeObjectOfClass:OCProcessSession.class forKey:@"processSession"];
		_resolved = [decoder decodeBoolForKey:@"resolved"];
	}

	return (self);
}

@end
