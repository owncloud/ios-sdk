//
//  OCSyncRecordActivity.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.01.19.
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

#import "OCSyncRecordActivity.h"
#import "OCSyncAction.h"
#import "OCWaitConditionIssue.h"

@interface OCSyncRecord (WaitingForUser)

@property(readonly) BOOL waitingForUser;

@end

@implementation OCSyncRecord (WaitingForUser)

- (BOOL)waitingForUser
{
	if (_state == OCSyncRecordStateProcessing)
	{
		for (OCWaitCondition *waitCondition in self.waitConditions)
		{
			if ([waitCondition isKindOfClass:OCWaitConditionIssue.class])
			{
				return (YES);
			}
		}
	}

	return (NO);
}

- (NSString *)waitConditionDescription
{
	if (_waitConditions.firstObject.localizedDescription != nil)
	{
		return (_waitConditions.firstObject.localizedDescription);
	}

	return (nil);
}

@end

@implementation OCSyncRecordActivity

- (instancetype)initWithSyncRecord:(OCSyncRecord *)syncRecord identifier:(OCActivityIdentifier)identifier
{
	if ((self = [super initWithIdentifier:identifier]) != nil)
	{
		_recordID = syncRecord.recordID;
		_type = syncRecord.action.actionEventType;
		self.recordState = syncRecord.state;
		self.waitingForUser = syncRecord.waitingForUser;

		_ranking = syncRecord.recordID.integerValue;
		_progress = [syncRecord.progress resolveWith:nil];

		_localizedDescription = syncRecord.action.localizedDescription;
	}

	return (self);
}

- (void)setRecordState:(OCSyncRecordState)recordState
{
	if ((_recordState != recordState) || (_localizedStatusMessage == nil))
	{
		_recordState = recordState;

		[self _computeStateAndMessage];
	}
}

- (void)setWaitingForUser:(BOOL)waitingForUser
{
	if ((_waitingForUser != waitingForUser) || (_localizedStatusMessage == nil))
	{
		_waitingForUser = waitingForUser;

		[self _computeStateAndMessage];
	}
}

- (void)setWaitConditionDescription:(NSString *)waitConditionDescription
{
	if ((![_waitConditionDescription isEqual:waitConditionDescription]) || (_localizedStatusMessage == nil))
	{
		_waitConditionDescription = waitConditionDescription;

		[self _computeStateAndMessage];
	}
}

- (void)_computeStateAndMessage
{
	switch (_recordState)
	{
		case OCSyncRecordStatePending:
		case OCSyncRecordStateReady:
			self.state = OCActivityStatePending;
			self.localizedStatusMessage = (_waitConditionDescription != nil) ? _waitConditionDescription : OCLocalized(@"Pending");
		break;

		case OCSyncRecordStateProcessing:
		case OCSyncRecordStateCompleted:
			if (self.waitingForUser)
			{
				self.state = OCActivityStatePaused;
				self.localizedStatusMessage = (_waitConditionDescription != nil) ? _waitConditionDescription : OCLocalized(@"Waiting for user");
			}
			else
			{
				self.state = OCActivityStateRunning;
				self.localizedStatusMessage = OCLocalized(@"Running");
			}
		break;

		case OCSyncRecordStateFailed:
			self.state = OCActivityStateFailed;
			self.localizedStatusMessage = OCLocalized(@"Failed");
		break;
	}
}

@end

@implementation OCActivityUpdate (OCSyncRecord)

- (instancetype)withSyncRecord:(OCSyncRecord *)syncRecord
{
	_updatesByKeyPath[@"recordState"] = @(syncRecord.state);
	_updatesByKeyPath[@"waitingForUser"] = @(syncRecord.waitingForUser);
	_updatesByKeyPath[@"waitConditionDescription"] = (syncRecord.waitConditionDescription != nil) ? syncRecord.waitConditionDescription : NSNull.null;

	return (self);
}

@end

