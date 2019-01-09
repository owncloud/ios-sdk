//
//  OCSyncContext.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.06.18.
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

#import "OCSyncContext.h"
#import "OCLogger.h"
#import "OCSyncRecord.h"
#import "OCSyncIssue.h"
#import "OCWaitConditionIssue.h"

@interface OCSyncContext ()
{
	BOOL _canHandleErrors;
}

@end

@implementation OCSyncContext

+ (instancetype)preflightContextWithSyncRecord:(OCSyncRecord *)syncRecord
{
	OCSyncContext *syncContext = [OCSyncContext new];

	syncContext.syncRecord = syncRecord;
	syncContext->_canHandleErrors = YES;

	return (syncContext);
}

+ (instancetype)schedulerContextWithSyncRecord:(OCSyncRecord *)syncRecord
{
	OCSyncContext *syncContext = [OCSyncContext new];

	syncContext.syncRecord = syncRecord;

	return (syncContext);
}

+ (instancetype)descheduleContextWithSyncRecord:(OCSyncRecord *)syncRecord
{
	OCSyncContext *syncContext = [OCSyncContext new];

	syncContext.syncRecord = syncRecord;

	return (syncContext);
}

+ (instancetype)eventHandlingContextWith:(OCSyncRecord *)syncRecord event:(OCEvent *)event
{
	OCSyncContext *syncContext = [OCSyncContext new];

	syncContext.syncRecord = syncRecord;
	syncContext.event = event;

	return (syncContext);
}

+ (instancetype)waitConditionRecoveryContextWith:(OCSyncRecord *)syncRecord
{
	OCSyncContext *syncContext = [OCSyncContext new];

	syncContext.syncRecord = syncRecord;

	return (syncContext);
}

- (void)addWaitCondition:(OCWaitCondition *)waitCondition
{
	@synchronized(self)
	{
		if (_queuedWaitConditions == nil)
		{
			_queuedWaitConditions = [NSMutableArray new];
		}

		[_queuedWaitConditions addObject:waitCondition];
	}
}

- (void)addSyncIssue:(OCSyncIssue *)syncIssue
{
	if (syncIssue == nil) { return; }

	[self addWaitCondition:[syncIssue makeWaitCondition]];
}

#pragma mark - State
- (void)transitionToState:(OCSyncRecordState)state withWaitConditions:(nullable NSArray <OCWaitCondition *> *)waitConditions
{
	@synchronized(self)
	{
		if ((waitConditions != nil) && (_queuedWaitConditions != nil) && (_queuedWaitConditions != waitConditions))
		{
			[_queuedWaitConditions addObjectsFromArray:waitConditions];
			waitConditions = _queuedWaitConditions;
			_queuedWaitConditions = nil;
		}
		else if ((waitConditions == nil) && (_queuedWaitConditions.count > 0))
		{
			waitConditions = _queuedWaitConditions;
			_queuedWaitConditions = nil;
		}
	}

	[_syncRecord transitionToState:state withWaitConditions:waitConditions];
	_updateStoredSyncRecordAfterItemUpdates = YES;
}

- (void)completeWithError:(nullable NSError *)error core:(OCCore *)core item:(nullable OCItem *)item parameter:(nullable id)parameter
{
	[_syncRecord completeWithError:error core:core item:item parameter:parameter];
	_updateStoredSyncRecordAfterItemUpdates = YES;
}

- (void)setError:(NSError *)error
{
	_error = error;

	if (!_canHandleErrors)
	{
		OCLogError(@"Error set to sync context that doesn't handle them: error=%@", error);
	}
}

@end
