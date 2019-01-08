//
//  OCWaitConditionPendingUserInteraction.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.12.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2018, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCWaitConditionPendingUserInteraction.h"
#import "OCProcessManager.h"
#import "NSError+OCError.h"

@implementation OCWaitConditionPendingUserInteraction

+ (instancetype)waitForUserInteractionWithIdentifier:(id<NSObject,NSSecureCoding>)userInteractionIdentifier inProcessSession:(OCProcessSession *)processSession
{
	OCWaitConditionPendingUserInteraction *blockingReason = [OCWaitConditionPendingUserInteraction new];

	blockingReason.userInteractionIdentifier = userInteractionIdentifier;
	blockingReason.processSession = processSession;

	return (blockingReason);
}

- (void)evaluateWithOptions:(NSDictionary<OCWaitConditionOption,id> *)options completionHandler:(OCWaitConditionEvaluationResultHandler)completionHandler
{
	NSArray *unfinishedIdentifiers;

	if (completionHandler == nil) { return; }

	// Check if process is still valid
	if (![[OCProcessManager sharedProcessManager] isSessionValid:_processSession usingThoroughChecks:YES])
	{
		// Process no longer valid => wait condition fails with error
		completionHandler(OCWaitConditionStateFail, NO, OCError(OCErrorInvalidProcess));
		return;
	}

	// Check unfinished identifiers
	if ((unfinishedIdentifiers = [options objectForKey:OCWaitConditionOptionPendingUserInteractionIdentifiers]) != nil)
	{
		if (![unfinishedIdentifiers containsObject:self.userInteractionIdentifier])
		{
			// User interaction is not unfinished, so it must be finished => proceed.
			completionHandler(OCWaitConditionStateProceed, NO, nil);
			return;
		}
	}

	// Condition not yet met => continue to wait
	completionHandler(OCWaitConditionStateWait, NO, nil);
}

@end

OCWaitConditionOption OCWaitConditionOptionPendingUserInteractionIdentifiers = @"pendingUserInteractionIdentifiers";
