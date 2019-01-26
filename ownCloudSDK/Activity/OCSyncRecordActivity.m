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

@implementation OCSyncRecordActivity

- (instancetype)initWithSyncRecord:(OCSyncRecord *)syncRecord
{
	if ((self = [super init]) != nil)
	{
		_recordID = syncRecord.recordID;
		_type = syncRecord.action.actionEventType;
		self.recordState = syncRecord.state;

		_ranking = syncRecord.recordID.integerValue;
		_progress = syncRecord.progress;

		_localizedDescription = syncRecord.action.localizedDescription;
	}

	return (self);
}

- (void)setRecordState:(OCSyncRecordState)recordState
{
	if ((_recordState != recordState) || (_localizedStatusMessage == nil))
	{
		_recordState = recordState;

		switch (_recordState)
		{
			case OCSyncRecordStatePending:
			break;

			case OCSyncRecordStateReady:
			break;

			case OCSyncRecordStateProcessing:
			break;

			case OCSyncRecordStateCompleted:
			break;

			case OCSyncRecordStateFailed:
			break;
		}
	}
}

@end
