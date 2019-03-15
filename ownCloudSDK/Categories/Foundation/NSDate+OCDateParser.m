//
//  NSDate+OCDateParser.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 10.03.18.
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

#import "NSDate+OCDateParser.h"

@implementation NSDate (OCDateParser)

+ (NSDateFormatter *)_ocDateFormatter
{
	static NSDateFormatter *dateFormatter;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		if ((dateFormatter = [NSDateFormatter new]) != nil)
		{
			[dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
			[dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
			[dateFormatter setDateFormat:@"EEE, dd MMM y HH:mm:ss zzz"];
		}
	});

	return (dateFormatter);
}

+ (NSDateFormatter *)_ocDateFormatterCompactUTC
{
	static NSDateFormatter *dateFormatter;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		if ((dateFormatter = [NSDateFormatter new]) != nil)
		{
			[dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
			[dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
			[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
		}
	});

	return (dateFormatter);
}

+ (instancetype)dateParsedFromString:(NSString *)dateString error:(NSError **)error
{
	return ([[self _ocDateFormatter] dateFromString:dateString]);
}

- (NSString *)davDateString
{
	return ([[[self class] _ocDateFormatter] stringFromDate:self]);
}

+ (instancetype)dateParsedFromCompactUTCString:(NSString *)dateString error:(NSError **)error
{
	return ([[self _ocDateFormatterCompactUTC] dateFromString:dateString]);
}

- (NSString *)compactUTCString
{
	return ([[[self class] _ocDateFormatterCompactUTC] stringFromDate:self]);
}

- (NSString *)compactUTCStringDateOnly
{
	NSString *dateString = [[[self class] _ocDateFormatterCompactUTC] stringFromDate:self];

	if (dateString.length >= 10)
	{
		return ([dateString substringToIndex:10]);
	}

	return (nil);
}

@end
