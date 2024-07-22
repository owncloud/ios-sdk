//
//  OCWaitConditionAvailableOffline.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 22.07.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCWaitConditionAvailableOffline.h"
#import "OCSyncAction.h"

@implementation OCWaitConditionAvailableOffline

- (void)evaluateWithOptions:(OCWaitConditionOptions)options completionHandler:(OCWaitConditionEvaluationResultHandler)completionHandler
{
	OCCore *core = options[OCWaitConditionOptionCore];
	OCSyncRecord *syncRecord = options[OCWaitConditionOptionSyncRecord];
	OCItem *item = syncRecord.action.localItem;

	if ((core != nil) && (item != nil))
	{
		OCCoreAvailableOfflineCoverage availableOfflineCoverage;
		availableOfflineCoverage = [core availableOfflinePolicyCoverageOfItem:item]; // Attention: this method only performs a QUICK check based on location, not actual policy conditions, so when Available Offline is implemented for Saved Searches, this must be changed to a precise implementation

		switch (availableOfflineCoverage)
		{
			case OCCoreAvailableOfflineCoverageNone:
				// File not / no longer included in available offline scope
				OCLogDebug(@"AOCheck: Cancelled %@", item.location.string);
				completionHandler(OCWaitConditionStateDeschedule, NO, OCError(OCErrorCancelled));
				return;
			break;

			case OCCoreAvailableOfflineCoverageIndirect:
			case OCCoreAvailableOfflineCoverageDirect:
				// File is included in available offline scope
				OCLogDebug(@"AOCheck: Approved %@", item.location.string);
				completionHandler(OCWaitConditionStateProceed, NO, nil);
				return;
			break;
		}
	}
	else
	{
		// Core and item are the minimum needed to make a decision
		OCLogDebug(@"AOCheck: Failed 1 %@", item.location.string);
		completionHandler(OCWaitConditionStateFail, NO, OCError(OCErrorInsufficientParameters));
		return;
	}

	OCLogDebug(@"AOCheck: Failed 2 %@", item.location.string);
	completionHandler(OCWaitConditionStateFail, NO, OCError(OCErrorInternal)); // Catch-all that should never be hit
}


#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder
{
	[super encodeWithCoder:coder];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)decoder
{
	return ([super initWithCoder:decoder]);
}

@end
