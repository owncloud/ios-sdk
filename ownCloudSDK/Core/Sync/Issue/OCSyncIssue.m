//
//  OCSyncIssue.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 19.12.18.
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

#import "OCSyncIssue.h"
#import "OCSyncRecord.h"
#import "OCWaitConditionIssue.h"

@implementation OCSyncIssue

+ (instancetype)issueForSyncRecord:(OCSyncRecord *)syncRecord level:(OCIssueLevel)level title:(NSString *)title description:(nullable NSString *)description metaData:(nullable NSDictionary<NSString*, id<NSSecureCoding>> *)metaData choices:(NSArray <OCSyncIssueChoice *> *)choices
{
	OCSyncIssue *issue = [self new];

	issue->_syncRecordID = syncRecord.recordID;

	issue.level = level;
	issue.localizedTitle = title;
	issue.localizedDescription = description;
	issue.metaData = metaData;
	issue.choices = choices;

	return (issue);
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_creationDate = [NSDate new];
		_uuid = [NSUUID UUID];
	}

	return (self);
}

- (OCWaitConditionIssue *)makeWaitCondition
{
	return ([OCWaitConditionIssue waitForIssueResolution:self]);
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
		_syncRecordID = [decoder decodeObjectOfClass:[NSNumber class] forKey:@"syncRecordID"];

		_uuid = [decoder decodeObjectOfClass:[NSUUID class] forKey:@"uuid"];
		_creationDate = [decoder decodeObjectOfClass:[NSDate class] forKey:@"creationDate"];

		_level = [decoder decodeIntegerForKey:@"level"];
		_localizedTitle = [decoder decodeObjectOfClass:[NSString class] forKey:@"title"];
		_localizedDescription = [decoder decodeObjectOfClass:[NSString class] forKey:@"desc"];
		_metaData = [decoder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"metaData"];
		_choices = [decoder decodeObjectOfClasses:[[NSSet alloc] initWithObjects:NSArray.class, OCSyncIssueChoice.class, nil] forKey:@"choices"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_syncRecordID forKey:@"syncRecordID"];

	[coder encodeObject:_uuid forKey:@"uuid"];
	[coder encodeObject:_creationDate forKey:@"creationDate"];

	[coder encodeInteger:_level forKey:@"level"];
	[coder encodeObject:_localizedTitle forKey:@"title"];
	[coder encodeObject:_localizedDescription forKey:@"desc"];
	[coder encodeObject:_metaData forKey:@"metaData"];
	[coder encodeObject:_choices forKey:@"choices"];
}

OCEventUserInfoKey OCEventUserInfoKeySyncIssue = @"syncIssue";

@end
