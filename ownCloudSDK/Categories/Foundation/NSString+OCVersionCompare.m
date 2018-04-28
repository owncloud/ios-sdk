//
//  NSString+OCVersionCompare.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 26.04.18.
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

#import "NSString+OCVersionCompare.h"

@implementation NSString (OCVersionCompare)

- (NSComparisonResult)compareVersionWith:(NSString *)otherVersion
{
	NSArray <NSString *> *selfVersionParts = [self componentsSeparatedByString:@"."];
	NSArray <NSString *> *otherVersionParts = [otherVersion componentsSeparatedByString:@"."];
	NSUInteger comparePartsCount = MIN(selfVersionParts.count, otherVersionParts.count);

	for (NSUInteger i=0; i<comparePartsCount; i++)
	{
		NSInteger selfVersionDigit = selfVersionParts[i].integerValue;
		NSInteger otherVersionDigit = otherVersionParts[i].integerValue;

		if (selfVersionDigit > otherVersionDigit)
		{
			return (NSOrderedDescending);
		}
		else if (selfVersionDigit < otherVersionDigit)
		{
			return (NSOrderedAscending);
		}
	}

	for (NSUInteger i=comparePartsCount; i < selfVersionParts.count; i++)
	{
		if (selfVersionParts[i].integerValue != 0)
		{
			return (NSOrderedDescending);
		}
	}

	for (NSUInteger i=comparePartsCount; i < otherVersionParts.count; i++)
	{
		if (otherVersionParts[i].integerValue != 0)
		{
			return (NSOrderedAscending);
		}
	}

	return (NSOrderedSame);
}

@end
