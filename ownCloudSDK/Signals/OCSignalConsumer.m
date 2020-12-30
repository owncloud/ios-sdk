//
//  OCSignalConsumer.m
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

#import "OCAppIdentity.h"
#import "OCSignalConsumer.h"

@implementation OCSignalConsumer

- (instancetype)initWithSignalUUID:(OCSignalUUID)signalUUID runIdentifier:(OCCoreRunIdentifier)runIdentifier handler:(OCSignalHandler)handler
{
	if ((self = [super init]) != nil)
	{
		_uuid = NSUUID.UUID.UUIDString;
		_signalUUID = signalUUID;

		_runIdentifier = runIdentifier;
		_componentIdentifier = OCAppIdentity.sharedAppIdentity.componentIdentifier;

		_signalHandler = [handler copy];
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
		_signalUUID = [coder decodeObjectOfClass:NSString.class forKey:@"signalUUID"];

		_runIdentifier = [coder decodeObjectOfClass:NSUUID.class forKey:@"runIdentifier"];
		_componentIdentifier = [coder decodeObjectOfClass:NSString.class forKey:@"componentIdentifier"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_uuid forKey:@"uuid"];
	[coder encodeObject:_signalUUID forKey:@"signalUUID"];

	[coder encodeObject:_runIdentifier forKey:@"runIdentifier"];
	[coder encodeObject:_componentIdentifier forKey:@"componentIdentifier"];
}

@end
