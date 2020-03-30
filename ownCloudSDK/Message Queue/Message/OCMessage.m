//
//  OCMessage.m
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

#import "OCMessage.h"
#import "OCCore.h"

@implementation OCMessage

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_date = [NSDate new];
		_uuid = [NSUUID new];
	}

	return (self);
}

- (instancetype)initWithSyncIssue:(OCSyncIssue *)syncIssue fromCore:(OCCore *)core
{
	if ((self = [super init]) != nil)
	{
		_date = syncIssue.creationDate;
		_uuid = syncIssue.uuid;

		_categoryIdentifier = syncIssue.templateIdentifier;

		_syncIssue = syncIssue;
		_bookmarkUUID = core.bookmark.uuid;
	}

	return (self);
}

- (BOOL)handled
{
	return (_syncIssueChoice != nil);
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
		_uuid = [decoder decodeObjectOfClass:NSUUID.class forKey:@"uuid"];

		_categoryIdentifier = [decoder decodeObjectOfClass:NSString.class forKey:@"categoryIdentifier"];
		_threadIdentifier = [decoder decodeObjectOfClass:NSString.class forKey:@"threadIdentifier"];

		_bookmarkUUID = [decoder decodeObjectOfClass:NSUUID.class forKey:@"bookmarkUUID"];

		_syncIssue = [decoder decodeObjectOfClass:OCSyncIssue.class forKey:@"syncIssue"];
		_syncIssueChoice = [decoder decodeObjectOfClass:OCSyncIssueChoice.class forKey:@"syncIssueChoice"];

		_processedBy = [decoder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"processedBy"];
		_lockingProcess = [decoder decodeObjectOfClass:OCProcessSession.class forKey:@"lockingProcess"];

		_presentedToUser = [decoder decodeBoolForKey:@"presentedToUser"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_date forKey:@"date"];
	[coder encodeObject:_uuid forKey:@"uuid"];

	[coder encodeObject:_categoryIdentifier forKey:@"categoryIdentifier"];
	[coder encodeObject:_threadIdentifier forKey:@"threadIdentifier"];

	[coder encodeObject:_bookmarkUUID forKey:@"bookmarkUUID"];

	[coder encodeObject:_syncIssue forKey:@"syncIssue"];
	[coder encodeObject:_syncIssueChoice forKey:@"syncIssueChoice"];

	[coder encodeObject:_processedBy forKey:@"processedBy"];
	[coder encodeObject:_lockingProcess forKey:@"lockingProcess"];

	[coder encodeBool:_presentedToUser forKey:@"presentedToUser"];
}

@end
