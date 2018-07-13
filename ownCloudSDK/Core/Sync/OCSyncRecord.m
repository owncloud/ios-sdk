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

@implementation OCSyncRecord

@synthesize recordID = _recordID;

@synthesize action = _action;
@synthesize timestamp = _timestamp;

@synthesize inProgressSince = _inProgressSince;
@synthesize state = _state;
@synthesize blockedByBundleIdentifier = _blockedByBundleIdentifier;
@synthesize blockedByPID = _blockedByPID;
@synthesize allowsRescheduling = _allowsRescheduling;

@synthesize archivedServerItem = _archivedServerItem;

@synthesize parameters = _parameters;

@synthesize resultHandler = _resultHandler;

#pragma mark - Init & Dealloc
- (instancetype)initWithAction:(OCSyncAction)action archivedServerItem:(OCItem *)archivedServerItem parameters:(NSDictionary <OCSyncActionParameter, id> *)parameters resultHandler:(OCCoreActionResultHandler)resultHandler
{
	if ((self = [self init]) != nil)
	{
		_action = action;
		_timestamp = [NSDate date];

		_state = OCSyncRecordStatePending;

		_archivedServerItem = archivedServerItem;
		_parameters = parameters;

		_resultHandler = [resultHandler copy];
	}

	return (self);
}

#pragma mark - Properties
- (NSData *)_archivedServerItemData
{
	if ((_archivedServerItemData == nil) && (_archivedServerItem != nil))
	{
		_archivedServerItemData = [NSKeyedArchiver archivedDataWithRootObject:_archivedServerItem];
	}

	return (_archivedServerItemData);
}

- (OCItem *)archivedServerItem
{
	if ((_archivedServerItem == nil) && (_archivedServerItemData != nil))
	{
		_archivedServerItem = [NSKeyedUnarchiver unarchiveObjectWithData:_archivedServerItemData];
	}

	return (_archivedServerItem);
}

- (OCItem *)item
{
	return (self.parameters[OCSyncActionParameterItem]);
}

- (OCPath)itemPath
{
	if (_itemPath == nil)
	{
		if ((_itemPath = self.parameters[OCSyncActionParameterPath]) == nil)
		{
			if ((_itemPath = ((OCItem *)self.parameters[OCSyncActionParameterItem]).path) == nil)
			{
				_itemPath = self.parameters[OCSyncActionParameterSourcePath];
			}
		}
	}

	return (_itemPath);
}

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

		_action = [decoder decodeObjectOfClass:[NSString class] forKey:@"action"];
		_timestamp = [decoder decodeObjectOfClass:[NSDate class] forKey:@"timestamp"];

		_state = (OCSyncRecordState)[decoder decodeIntegerForKey:@"state"];
		_inProgressSince = [decoder decodeObjectOfClass:[NSDate class] forKey:@"inProgressSince"];
		_blockedByBundleIdentifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"blockedByBundleIdentifier"];
		_blockedByPID = [decoder decodeObjectOfClass:[NSNumber class] forKey:@"blockedByPID"];
		_allowsRescheduling = [decoder decodeBoolForKey:@"allowsRescheduling"];

		_archivedServerItemData = [decoder decodeObjectOfClass:[NSData class] forKey:@"archivedServerItemData"];

		_parameters = [decoder decodeObjectOfClass:[NSDictionary class] forKey:@"parameters"];
	}
	
	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_recordID forKey:@"recordID"];

	[coder encodeObject:_action forKey:@"action"];
	[coder encodeObject:_timestamp forKey:@"timestamp"];

	[coder encodeInteger:(NSInteger)_state forKey:@"state"];
	[coder encodeObject:_inProgressSince forKey:@"inProgressSince"];
	[coder encodeObject:_blockedByBundleIdentifier forKey:@"blockedByBundleIdentifier"];
	[coder encodeObject:_blockedByPID forKey:@"blockedByPID"];
	[coder encodeBool:_allowsRescheduling forKey:@"allowsRescheduling"];

	[coder encodeObject:[self _archivedServerItemData] forKey:@"archivedServerItemData"];

	[coder encodeObject:_parameters forKey:@"parameters"];
}

@end

OCSyncAction OCSyncActionDeleteLocal = @"deleteLocal";
OCSyncAction OCSyncActionDeleteRemote = @"deleteRemote";
OCSyncAction OCSyncActionMove = @"move";
OCSyncAction OCSyncActionCopy = @"copy";
OCSyncAction OCSyncActionCreateFolder = @"createFolder";
OCSyncAction OCSyncActionUpload = @"upload";
OCSyncAction OCSyncActionDownload = @"download";

OCSyncActionParameter OCSyncActionParameterParentItem = @"parentItem";
OCSyncActionParameter OCSyncActionParameterItem = @"item";
OCSyncActionParameter OCSyncActionParameterPath = @"path";
OCSyncActionParameter OCSyncActionParameterSourcePath = @"sourcePath";
OCSyncActionParameter OCSyncActionParameterTargetPath = @"targetPath";
OCSyncActionParameter OCSyncActionParameterSourceItem = @"sourceItem";
OCSyncActionParameter OCSyncActionParameterTargetItem = @"targetItem";
OCSyncActionParameter OCSyncActionParameterTargetName = @"targetName";
OCSyncActionParameter OCSyncActionParameterRequireMatch = @"requireMatch";

