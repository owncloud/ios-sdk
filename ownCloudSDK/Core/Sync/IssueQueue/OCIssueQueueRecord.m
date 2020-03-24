//
//  OCIssueQueueRecord.m
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

#import "OCIssueQueueRecord.h"

@implementation OCIssueQueueRecord

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_date = [NSDate new];
	}

	return (self);
}

#pragma mark - En-/Decoding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [self init]) != nil)
	{
		_date = [decoder decodeObjectOfClass:NSDate.class forKey:@"date"];
		_syncIssue = [decoder decodeObjectOfClass:OCSyncIssue.class forKey:@"syncIssue"];
		_presentedToUser = [decoder decodeBoolForKey:@"presentedToUser"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_date forKey:@"date"];
	[coder encodeObject:_syncIssue forKey:@"syncIssue"];
	[coder encodeBool:_presentedToUser forKey:@"presentedToUser"];
}

@end
