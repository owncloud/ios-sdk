//
//  NSProgress+OCEvent.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.02.18.
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

#import "NSProgress+OCEvent.h"

@implementation NSProgress (OCEvent)

- (OCEventType)eventType
{
	return ([self.userInfo[@"_eventType"] unsignedIntegerValue]);
}

- (void)setEventType:(OCEventType)eventType
{
	[self setUserInfoObject:@(eventType) forKey:@"_eventType"];
}

- (OCFileID)fileID
{
	return (self.userInfo[@"_fileID"]);
}

- (void)setFileID:(OCFileID)fileID
{
	[self setUserInfoObject:fileID forKey:@"_fileID"];
}

- (OCLocalID)localID
{
	return (self.userInfo[@"_localID"]);
}

- (void)setLocalID:(OCLocalID)localID
{
	[self setUserInfoObject:localID forKey:@"_localID"];
}

- (OCConnectionJobID)jobID
{
	return (self.userInfo[@"_jobID"]);
}

- (void)setJobID:(OCConnectionJobID)jobID
{
	[self setUserInfoObject:jobID forKey:@"_jobID"];
}


@end
