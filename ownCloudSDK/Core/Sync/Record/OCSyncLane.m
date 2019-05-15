//
//  OCSyncLane.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 29.04.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCSyncLane.h"

@interface OCSyncLane ()
{
	NSMutableSet<OCSyncLaneTag> *_tags;
}
@end

@implementation OCSyncLane

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_tags = [NSMutableSet new];
	}

	return (self);
}

#pragma mark - Tag interface
- (BOOL)coversTags:(nullable NSSet <OCSyncLaneTag> *)tags prefixMatches:(nullable NSUInteger *)outPrefixMatches identicalTags:(nullable NSUInteger *)outIdenticalMatches
{
	NSUInteger identicalMatches = 0, prefixMatches = 0;

	if (tags == nil) { return(NO); }

	@synchronized (_tags)
	{
		for (OCSyncLaneTag checkTag in tags)
		{
			if (![checkTag isEqual:@"/"]) // "/" is not to be considered (would match ALL tag sets)
			{
				for (OCSyncLaneTag laneTag in _tags)
				{
					if ([laneTag isEqualToString:checkTag])
					{
						identicalMatches++;
					}
					else
					{
						if ([laneTag  hasPrefix:checkTag] ||
						    [checkTag hasPrefix:laneTag])
						{
							prefixMatches++;
						}
					}
				}
			}
		}
	}

	if (outPrefixMatches != NULL)
	{
		*outPrefixMatches = prefixMatches;
	}

	if (outIdenticalMatches != NULL)
	{
		*outIdenticalMatches = identicalMatches;
	}

	return ((identicalMatches > 0) || (prefixMatches > 0));
}

- (void)extendWithTags:(nullable NSSet <OCSyncLaneTag> *)tags
{
	if (tags == nil) { return; }

	@synchronized (_tags)
	{
		[_tags unionSet:tags];
		[_tags removeObject:@"/"]; // "/" is not to be considered (would match ALL tag sets)
	}
}

#pragma mark - Secure coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		_identifier = [decoder decodeObjectOfClass:[NSNumber class] forKey:@"identifier"];
		_afterLanes = [decoder decodeObjectOfClasses:[[NSSet alloc] initWithObjects:[NSSet class], [NSNumber class], nil] forKey:@"afterLanes"];

		_tags = [decoder decodeObjectOfClasses:[[NSSet alloc] initWithObjects:[NSSet class], [NSString class], nil] forKey:@"tags"];
		if (_tags == nil) { _tags = [NSMutableSet new]; }
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_identifier forKey:@"identifier"];
	[coder encodeObject:_afterLanes forKey:@"afterLanes"];
	[coder encodeObject:_tags forKey:@"tags"];
}

#pragma mark - Description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p, identifier: %@%@, tags: %@>", NSStringFromClass(self.class), self, _identifier, ((_afterLanes.count>0) ? [NSString stringWithFormat:@", afterLanes=%@", _afterLanes] : @""), _tags]);
}

- (NSString *)privacyMaskedDescription
{
	return ([NSString stringWithFormat:@"<%@: %p, identifier: %@%@>", NSStringFromClass(self.class), self, _identifier, ((_afterLanes.count>0) ? [NSString stringWithFormat:@", afterLanes=%@", _afterLanes] : @"")]);
}

@end
