//
//  OCSyncRecord.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.02.18.
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

#import "OCSyncRecord.h"
#import "NSProgress+OCExtensions.h"
#import "OCSyncAction.h"

@implementation OCSyncRecord

@synthesize recordID = _recordID;

@synthesize actionIdentifier = _actionIdentifier;
@synthesize action = _action;
@synthesize timestamp = _timestamp;

@synthesize state = _state;
@synthesize inProgressSince = _inProgressSince;

@synthesize blockedByBundleIdentifier = _blockedByBundleIdentifier;
@synthesize blockedByPID = _blockedByPID;
@dynamic blockedByDifferentCopyOfThisProcess;

@synthesize allowsRescheduling = _allowsRescheduling;

@synthesize resultHandler = _resultHandler;
@synthesize progress = _progress;

#pragma mark - Init & Dealloc
- (instancetype)initWithAction:(OCSyncAction *)action resultHandler:(OCCoreActionResultHandler)resultHandler
{
	if ((self = [self init]) != nil)
	{
		_action = action;
		_actionIdentifier = action.identifier;
		_timestamp = [NSDate date];

		_state = OCSyncRecordStatePending;

		_resultHandler = [resultHandler copy];
	}

	return (self);
}

#pragma mark - Properties
- (void)setState:(OCSyncRecordState)state
{
	_state = state;

	if (state == OCSyncRecordStateAwaitingUserInteraction)
	{
		self.blockedByBundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
		self.blockedByPID = @(getpid());
	}
	else
	{
		self.blockedByBundleIdentifier = nil;
		self.blockedByPID = nil;
	}
}

- (BOOL)blockedByDifferentCopyOfThisProcess
{
	if (_state == OCSyncRecordStateAwaitingUserInteraction)
	{
		if (([self.blockedByBundleIdentifier isEqual:[[NSBundle mainBundle] bundleIdentifier]] &&
		    (![self.blockedByPID isEqual:@(getpid())])))
		{
			return (YES);
		}
	}

	return (NO);
}

#pragma mark - Serialization
+ (instancetype)syncRecordFromSerializedData:(NSData *)serializedData
{
	if (serializedData==nil) { return(nil); }
	return ([NSKeyedUnarchiver unarchiveObjectWithData:serializedData]);
}

- (NSData *)serializedData
{
	return ([NSKeyedArchiver archivedDataWithRootObject:self]);
}

- (void)addProgress:(NSProgress *)progress
{
	if (progress != nil)
	{
		if (_progress == nil)
		{
			self.progress = progress;
		}
		else
		{
			_progress.localizedDescription = progress.localizedDescription;
			_progress.localizedAdditionalDescription = progress.localizedAdditionalDescription;

			_progress.totalUnitCount += 200;
			[_progress addChild:progress withPendingUnitCount:200];
		}
	}
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
		_recordID = [decoder decodeObjectOfClass:[NSNumber class] forKey:@"recordID"];

		_actionIdentifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"actionID"];
		_action = [decoder decodeObjectOfClass:[OCSyncRecord class] forKey:@"action"];

		_timestamp = [decoder decodeObjectOfClass:[NSDate class] forKey:@"timestamp"];

		_state = (OCSyncRecordState)[decoder decodeIntegerForKey:@"state"];
		_inProgressSince = [decoder decodeObjectOfClass:[NSDate class] forKey:@"inProgressSince"];
		_blockedByBundleIdentifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"blockedByBundleIdentifier"];
		_blockedByPID = [decoder decodeObjectOfClass:[NSNumber class] forKey:@"blockedByPID"];
		_allowsRescheduling = [decoder decodeBoolForKey:@"allowsRescheduling"];
	}
	
	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_recordID forKey:@"recordID"];

	[coder encodeObject:_actionIdentifier forKey:@"actionID"];
	[coder encodeObject:_action forKey:@"action"];

	[coder encodeObject:_timestamp forKey:@"timestamp"];

	[coder encodeInteger:(NSInteger)_state forKey:@"state"];
	[coder encodeObject:_inProgressSince forKey:@"inProgressSince"];
	[coder encodeObject:_blockedByBundleIdentifier forKey:@"blockedByBundleIdentifier"];
	[coder encodeObject:_blockedByPID forKey:@"blockedByPID"];
	[coder encodeBool:_allowsRescheduling forKey:@"allowsRescheduling"];
}

#pragma mark - Description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p, recordID: %@, actionID: %@, timestamp: %@, state: %lu, inProgressSince: %@, allowsRescheduling: %d, action: %@>", NSStringFromClass(self.class), self, _recordID, _actionIdentifier, _timestamp, _state, _inProgressSince, _allowsRescheduling, _action]);
}


@end

OCSyncActionIdentifier OCSyncActionIdentifierDeleteLocal = @"deleteLocal";
OCSyncActionIdentifier OCSyncActionIdentifierDeleteRemote = @"deleteRemote";
OCSyncActionIdentifier OCSyncActionIdentifierMove = @"move";
OCSyncActionIdentifier OCSyncActionIdentifierCopy = @"copy";
OCSyncActionIdentifier OCSyncActionIdentifierCreateFolder = @"createFolder";
OCSyncActionIdentifier OCSyncActionIdentifierDownload = @"download";
OCSyncActionIdentifier OCSyncActionIdentifierUpload = @"upload";
OCSyncActionIdentifier OCSyncActionIdentifierUpdate = @"update";
