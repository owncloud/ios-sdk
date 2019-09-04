//
//  OCEventRecord.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.09.19.
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

#import "OCEventRecord.h"

@implementation OCEventRecord

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_processSession = OCProcessManager.sharedProcessManager.processSession;
	}

	return (self);
}

- (instancetype)initWithEvent:(OCEvent *)event syncRecordID:(OCSyncRecordID)syncRecordID
{
	if ((self = [self init]) != nil)
	{
		_event = event;
		_syncRecordID = syncRecordID;
	}

	return (self);
}

#pragma mark - Secure coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		_event = [decoder decodeObjectOfClass:[OCEvent class] forKey:@"event"];
		_processSession = [decoder decodeObjectOfClass:[OCProcessSession class] forKey:@"processSession"];
		_syncRecordID = [decoder decodeObjectOfClass:[NSNumber class] forKey:@"syncRecordID"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_event forKey:@"event"];
	[coder encodeObject:_processSession forKey:@"processSession"];
	[coder encodeObject:_syncRecordID forKey:@"syncRecordID"];
}

@end
