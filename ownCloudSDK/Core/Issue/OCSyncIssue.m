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

@implementation OCSyncIssue

+ (instancetype)issueWithLevel:(OCIssueLevel)level title:(NSString *)title description:(nullable NSString *)description choices:(NSArray <OCSyncIssueChoice *> *)choices
{
	OCSyncIssue *issue = [self new];

	issue.level = level;
	issue.localizedTitle = title;
	issue.localizedDescription = description;
	issue.choices = choices;

	return (issue);
}

+ (instancetype)warningIssueWithTitle:(NSString *)title description:(nullable NSString *)description choices:(NSArray <OCSyncIssueChoice *> *)choices
{
	return ([self issueWithLevel:OCIssueLevelWarning title:title description:description choices:choices]);
}

+ (instancetype)errorIssueWithTitle:(NSString *)title description:(nullable NSString *)description choices:(NSArray <OCSyncIssueChoice *> *)choices
{
	return ([self issueWithLevel:OCIssueLevelError title:title description:description choices:choices]);
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

#pragma mark - En-/Decoding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [self init]) != nil)
	{
		_uuid = [decoder decodeObjectOfClass:[NSUUID class] forKey:@"uuid"];
		_creationDate = [decoder decodeObjectOfClass:[NSDate class] forKey:@"creationDate"];

		_level = [decoder decodeIntegerForKey:@"level"];
		_localizedTitle = [decoder decodeObjectOfClass:[NSString class] forKey:@"title"];
		_localizedDescription = [decoder decodeObjectOfClass:[NSString class] forKey:@"desc"];
		_choices = [decoder decodeObjectOfClass:[NSDictionary class] forKey:@"choices"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_uuid forKey:@"uuid"];
	[coder encodeObject:_creationDate forKey:@"creationDate"];

	[coder encodeInteger:_level forKey:@"level"];
	[coder encodeObject:_localizedTitle forKey:@"title"];
	[coder encodeObject:_localizedDescription forKey:@"desc"];
	[coder encodeObject:_choices forKey:@"choices"];
}

@end
