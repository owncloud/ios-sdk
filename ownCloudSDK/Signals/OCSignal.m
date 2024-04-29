//
//  OCSignal.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.09.20.
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

#import "OCSignal.h"
#import "OCEvent.h"

@implementation OCSignal

+ (OCSignalUUID)generateUUID
{
	return (NSUUID.UUID.UUIDString);
}

- (instancetype)initWithUUID:(OCSignalUUID)uuid payload:(OCCodableDict)payload
{
	if ((self = [super init]) != nil)
	{
		_uuid = uuid;
		_payload = payload;
	}

	return (self);
}

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if ((self = [super init]) != nil)
	{
		_uuid = [coder decodeObjectOfClass:NSString.class forKey:@"uuid"];
		_payload = [coder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"payload"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_uuid forKey:@"uuid"];
	[coder encodeObject:_payload forKey:@"payload"];
}

@end
