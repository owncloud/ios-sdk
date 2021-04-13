//
//  OCWaitCondition.m
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

#import "OCWaitCondition.h"

@implementation OCWaitCondition

@synthesize uuid = _uuid;

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_uuid = NSUUID.UUID;
	}

	return (self);
}

- (instancetype)withLocalizedDescription:(NSString *)localizedDescription
{
	self.localizedDescription = localizedDescription;

	return (self);
}

#pragma mark - Evaluation
- (void)evaluateWithOptions:(nullable OCWaitConditionOptions)options completionHandler:(OCWaitConditionEvaluationResultHandler)completionHandler
{
	completionHandler(OCWaitConditionStateProceed, NO, nil);
}

#pragma mark - Event handling
- (BOOL)handleEvent:(OCEvent *)event withOptions:(OCWaitConditionOptions)options sender:(id)sender
{
	return (NO);
}

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder
{
	[coder encodeObject:_uuid forKey:@"uuid"];
	[coder encodeObject:_localizedDescription forKey:@"localizedDescription"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		_uuid = [decoder decodeObjectOfClass:NSUUID.class forKey:@"uuid"];
		_localizedDescription = [decoder decodeObjectOfClass:NSString.class forKey:@"localizedDescription"];
	}

	return (self);
}

@end

OCWaitConditionOption OCWaitConditionOptionCore = @"core";
OCWaitConditionOption OCWaitConditionOptionSyncRecord = @"syncRecord";
OCWaitConditionOption OCWaitConditionOptionSyncContext = @"syncContext";

OCEventUserInfoKey OCEventUserInfoKeyWaitConditionUUID = @"waitConditionUUID";
