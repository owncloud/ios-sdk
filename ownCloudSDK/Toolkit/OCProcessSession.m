//
//  OCProcessSession.m
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

#import "OCProcessManager.h"
#import "OCProcessSession.h"
#import "OCLogger.h"

@implementation OCProcessSession

- (instancetype)initForProcess
{
	if ((self = [self init]) != nil)
	{
		_uuid = [NSUUID UUID];
		_bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
		_lastActive = [NSDate date];
		_bootTimestamp = [OCProcessManager bootTimestamp];

		_processType = OCProcessTypeApp;
		if ([NSBundle.mainBundle.bundlePath hasSuffix:@".appex"])
		{
			_processType = OCProcessTypeExtension;
		}
	}

	return (self);
}

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [self init]) != nil)
	{
		_uuid = [decoder decodeObjectOfClass:[NSUUID class] forKey:@"uuid"];
		_bundleIdentifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"bundleIdentifier"];
		_lastActive = [decoder decodeObjectOfClass:[NSDate class] forKey:@"lastActive"];
		_bootTimestamp = [decoder decodeObjectOfClass:[NSNumber class] forKey:@"bootTimestamp"];
		_processType = [decoder decodeIntegerForKey:@"processType"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_uuid forKey:@"uuid"];
	[coder encodeObject:_bundleIdentifier forKey:@"bundleIdentifier"];
	[coder encodeObject:_lastActive forKey:@"lastActive"];
	[coder encodeObject:_bootTimestamp forKey:@"bootTimestamp"];
	[coder encodeInteger:_processType forKey:@"processType"];
}

#pragma mark - Serialization tools
+ (instancetype)processSessionFromSerializedData:(NSData *)serializedData
{
	if (serializedData != nil)
	{
		return ([NSKeyedUnarchiver unarchiveObjectWithData:serializedData]);
	}

	return (nil);
}

- (nullable NSData *)serializedData
{
	NSData *serializedData = nil;

	@try {
		serializedData = ([NSKeyedArchiver archivedDataWithRootObject:self]);
	}
	@catch (NSException *exception) {
		OCLogError(@"Error serializing processSession=%@ with exception=%@", self, exception);
	}

	return (serializedData);
}

#pragma mark - Description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p, uuid: %@, bundleIdentifier: %@, lastActive: %@, bootTimestamp: %@, processType: %lu>", NSStringFromClass(self.class), self, _uuid, _bundleIdentifier, _lastActive, _bootTimestamp, _processType]);
}

@end
