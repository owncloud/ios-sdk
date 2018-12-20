//
//  OCBlockingReasonPendingUserInteraction.m
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

#import "OCBlockingReasonPendingUserInteraction.h"
#import "OCProcessManager.h"
#import "NSError+OCError.h"

@implementation OCBlockingReasonPendingUserInteraction

+ (instancetype)blockingPendingUserInteractionWithIdentifier:(id<NSSecureCoding>)userInteractionIdentifier inProcessSession:(OCProcessSession *)processSession
{
	OCBlockingReasonPendingUserInteraction *blockingReason = [OCBlockingReasonPendingUserInteraction new];

	blockingReason.userInteractionIdentifier = userInteractionIdentifier;
	blockingReason.processSession = processSession;

	return (blockingReason);
}

- (void)tryResolutionWithOptions:(NSDictionary<OCBlockingReasonOption,id> *)options completionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler
{
	NSArray *unfinishedIdentifiers;

	if (completionHandler == nil) { return; }

	// Check if process is still valid
	if (![[OCProcessManager sharedProcessManager] isSessionValid:_processSession usingThoroughChecks:YES])
	{
		completionHandler(YES, OCError(OCErrorInvalidProcess));
		return;
	}

	// Check unfinished identifiers
	unfinishedIdentifiers = [options objectForKey:OCBlockingReasonOptionPendingUserInteractionIdentifiers];

	if (![unfinishedIdentifiers containsObject:self.userInteractionIdentifier])
	{
		completionHandler(YES, nil);
		return;
	}

	// Resolution fails in all other cases
	completionHandler(NO, nil);
}

@end

OCBlockingReasonOption OCBlockingReasonOptionPendingUserInteractionIdentifiers = @"pendingUserInteractionIdentifiers";
