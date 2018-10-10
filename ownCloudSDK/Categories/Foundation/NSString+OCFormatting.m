//
//  NSString+OCFormatting.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 14.09.18.
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

#import "NSString+OCFormatting.h"

@implementation NSString (OCFormatting)

- (NSString *)leftPaddedMinLength:(NSUInteger)minWidth
{
	if (self.length < minWidth)
	{
		return ([self stringByPaddingToLength:minWidth withString:@" " startingAtIndex:0]);
	}

	return (self);
}

- (NSString *)rightPaddedMinLength:(NSUInteger)minWidth
{
	if (self.length < minWidth)
	{
		return ([[@"" stringByPaddingToLength:minWidth-self.length withString:@" " startingAtIndex:0] stringByAppendingString:self]);
	}

	return (self);
}

- (NSString *)leftPaddedMaxLength:(NSUInteger)maxWidth
{
	NSString *paddedString = [self leftPaddedMinLength:maxWidth];

	if (paddedString.length > maxWidth)
	{
		return ([[paddedString substringWithRange:NSMakeRange(0, maxWidth-1)] stringByAppendingString:@"…"]);
	}

	return (paddedString);
}

- (NSString *)rightPaddedMaxLength:(NSUInteger)maxWidth
{
	NSString *paddedString = [self rightPaddedMinLength:maxWidth];

	if (paddedString.length > maxWidth)
	{
		return ([@"…" stringByAppendingString:[paddedString substringWithRange:NSMakeRange(paddedString.length-maxWidth+1, maxWidth-1)]]);
	}

	return (paddedString);
}

@end
