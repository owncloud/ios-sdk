//
//  NSString+NameConflicts.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 29.06.19.
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

#import "NSString+NameConflicts.h"
#import "OCMacros.h"

@implementation NSString (NameConflicts)

- (void)splitIntoBaseName:(NSString * _Nullable * _Nullable)outBaseName extension:(NSString * _Nullable * _Nullable)outExtension
{
	NSRange extensionDotRange = [self rangeOfString:@"." options:NSBackwardsSearch];
	__block NSString *baseName = (extensionDotRange.location != NSNotFound) ? [self substringToIndex:extensionDotRange.location] : self;
	NSString *extension = (extensionDotRange.location != NSNotFound) ? [self substringFromIndex:extensionDotRange.location+1] : nil;

	if (outBaseName != NULL)
	{
		*outBaseName = baseName;
	}

	if (outExtension != NULL)
	{
		*outExtension = extension;
	}
}

- (NSString *)itemBaseNameWithStyle:(OCCoreDuplicateNameStyle * _Nullable)outStyle duplicateCount:(NSNumber * _Nullable * _Nullable)outDuplicateCount allowAmbiguous:(BOOL)allowAmbiguous
{
	__block NSNumber *duplicateCount = nil;
	__block OCCoreDuplicateNameStyle duplicateStyle = OCCoreDuplicateNameStyleNone;

	// Split itemName into baseName + extension
	__block NSString *baseName = nil;
	NSString *extension = nil;
	[self splitIntoBaseName:&baseName extension:&extension];

	// Determine if duplicate + duplicate format
	void (^AttemptDuplicateSplit)(NSString *prefix, NSString *oneSuffix, NSString *suffix, OCCoreDuplicateNameStyle style) = ^(NSString *prefix, NSString *oneSuffix, NSString *suffix, OCCoreDuplicateNameStyle style) {
		// Check for oneSuffix
		if (oneSuffix != nil)
		{
			if ([baseName.lowercaseString hasSuffix:oneSuffix.lowercaseString])
			{
				duplicateStyle = style;
				duplicateCount = @(1);

				baseName = [baseName substringToIndex:baseName.length - oneSuffix.length];

				return;
			}
		}

		// Check for prefix and suffix
		NSRange openingRange = [baseName rangeOfString:prefix options:NSBackwardsSearch|NSCaseInsensitiveSearch];

		if (openingRange.location != NSNotFound)
		{
			NSString *possibleNumberString = [baseName substringWithRange:NSMakeRange(openingRange.location+openingRange.length, baseName.length-openingRange.location-openingRange.length-suffix.length)];

			if ((possibleNumberString.length>0) && ([possibleNumberString stringByTrimmingCharactersInSet:[NSCharacterSet decimalDigitCharacterSet]].length == 0))
			{
				// possibleNumberString is actually a number string
				duplicateStyle = style;
				duplicateCount = @(possibleNumberString.integerValue);

				baseName = [baseName substringToIndex:openingRange.location];
			}
		}
	};

	if ([baseName hasSuffix:@")"])
	{
		AttemptDuplicateSplit(@" (", nil, @")",OCCoreDuplicateNameStyleBracketed);
	}
	else
	{
		AttemptDuplicateSplit(@" copy ", @" copy", @"", OCCoreDuplicateNameStyleCopy);
	}

	if (duplicateStyle == OCCoreDuplicateNameStyleNone)
	{
		NSString *localizedCopy = OCLocalized(@"copy");
		AttemptDuplicateSplit([NSString stringWithFormat:@" %@ ", localizedCopy], [NSString stringWithFormat:@" %@", localizedCopy], @"", OCCoreDuplicateNameStyleCopyLocalized);
	}

	if ((duplicateStyle == OCCoreDuplicateNameStyleNone) && allowAmbiguous)
	{
		AttemptDuplicateSplit(@" ", nil, @"", OCCoreDuplicateNameStyleNumbered);
	}

	// Return findings
	if (outStyle != NULL)
	{
		*outStyle = duplicateStyle;
	}

	if (outDuplicateCount != NULL)
	{
		*outDuplicateCount = duplicateCount;
	}

	if (extension != nil)
	{
		return ([baseName stringByAppendingPathExtension:extension]);
	}

	return (baseName);
}

- (NSString *)itemDuplicateNameWithStyle:(OCCoreDuplicateNameStyle)style duplicateCount:(NSNumber *)duplicateCount
{
	// Split itemName into baseName + extension
	NSString *baseName = nil, *extension = nil;
	[self splitIntoBaseName:&baseName extension:&extension];

	if (duplicateCount.integerValue == 0)
	{
		style = OCCoreDuplicateNameStyleNone;
	}

	switch (style)
	{
		case OCCoreDuplicateNameStyleNone:
			return (self);
		break;

		case OCCoreDuplicateNameStyleCopy:
			if (duplicateCount.unsignedIntegerValue == 1)
			{
				baseName = [baseName stringByAppendingString:@" copy"];
			}
			else
			{
				baseName = [baseName stringByAppendingFormat:@" copy %lu", duplicateCount.unsignedIntegerValue];
			}
		break;

		case OCCoreDuplicateNameStyleCopyLocalized:
			if (duplicateCount.unsignedIntegerValue == 1)
			{
				baseName = [baseName stringByAppendingFormat:@" %@", OCLocalized(@"copy")];
			}
			else
			{
				baseName = [baseName stringByAppendingFormat:@" %@ %lu", OCLocalized(@"copy"), duplicateCount.unsignedIntegerValue];
			}
		break;

		case OCCoreDuplicateNameStyleBracketed:
			baseName = [baseName stringByAppendingFormat:@" (%lu)", duplicateCount.unsignedIntegerValue];
		break;

		case OCCoreDuplicateNameStyleNumbered:
			baseName = [baseName stringByAppendingFormat:@" %lu", duplicateCount.unsignedIntegerValue];
		break;
	}

	if (extension != nil)
	{
		return ([baseName stringByAppendingPathExtension:extension]);
	}

	return (baseName);
}

@end
