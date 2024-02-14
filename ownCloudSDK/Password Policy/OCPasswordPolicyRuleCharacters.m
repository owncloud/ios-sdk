//
//  OCPasswordPolicyRuleCharacters.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 14.02.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCPasswordPolicyRuleCharacters.h"
#import "OCMacros.h"
#import "OCLocale.h"
#import "OCLocaleFilterVariables.h"

@implementation OCPasswordPolicyRuleCharacters

- (instancetype)initWithCharacters:(nullable NSString *)characters characterSet:(nullable NSCharacterSet *)characterSet minimumCount:(NSNumber *)minimumCount maximumCount:(NSNumber *)maximumCount localizedDescription:(NSString *)localizedDescription localizedName:(nonnull NSString *)localizedName
{
	if ((self = [super initWithLocalizedDescription:localizedDescription]) != nil)
	{
		self.validCharacters = characters;

		// Use passed character set. If none was passed, generate one from the passed characters, if any.
		self.validCharactersSet = (characterSet != nil) ? characterSet : ((characters != nil) ? [NSCharacterSet characterSetWithCharactersInString:characters] : nil);

		self.minimumCount = minimumCount;
		self.maximumCount = maximumCount;

		self.localizedName = localizedName;

		if (localizedDescription == nil)
		{
			// Generate a description from building blocks
			if (minimumCount != nil)
			{
				if (maximumCount != nil)
				{
					// Minimum + Maximum count
					localizedDescription = OCLocalizedFormat(@"Between {{min}} and {{max}} {{characterType}}", (@{
						@"min" : minimumCount.stringValue,
						@"max" : maximumCount.stringValue,
						@"characterType" : localizedName
					}));
				}
				else
				{
					// Minimum count only
					localizedDescription = OCLocalizedFormat(@"At least {{min}} {{characterType}}", (@{
						@"min" : minimumCount.stringValue,
						@"characterType" : localizedName
					}));
				}
			}
			else if (maximumCount != nil)
			{
				// Maximum count only
				localizedDescription = OCLocalizedFormat(@"At most {{max}} {{characterType}}", (@{
					@"max" : maximumCount.stringValue,
					@"characterType" : localizedName
				}));
			}
		}
	}

	return (self);
}

- (NSUInteger)charactersMatchCountIn:(NSString *)password
{
	NSUInteger len = password.length;
	NSUInteger matches = 0;

	if (_validCharactersSet != nil)
	{
		// Count number of occurences of characters in the set
		for (NSUInteger offset=0; offset < len; offset++)
		{
			NSString *singleCharString;

			if ((singleCharString = [password substringWithRange:NSMakeRange(offset, 1)]) != nil)
			{
				unichar singleUnichar = [singleCharString characterAtIndex:0];

				if ([_validCharactersSet characterIsMember:singleUnichar])
				{
					matches++;
				}
			}
		}
	}
	else
	{
		// No special characters required by this rule - all characters match.
		// Therefore use the length of the password as number of matches.
		matches = password.length;
	}

	return (matches);
}

- (NSString *)validate:(NSString *)password
{
	NSUInteger matches = [self charactersMatchCountIn:password];

	if (self.minimumCount != nil)
	{
		// Minimum count provided
		if (matches < self.minimumCount.unsignedIntegerValue)
		{
			// Minimum number of matches not reached => return error
			return (OCLocalizedFormat(@"Too few {{localizedName}}", @{
				@"localizedName" : _localizedName
			}));
		}
	}

	if (self.maximumCount != nil)
	{
		// Maximum count provided
		if (matches > self.maximumCount.unsignedIntegerValue)
		{
			// Maximum number of matches not reached => return error
			return (OCLocalizedFormat(@"Too many {{localizedName}}", @{
				@"localizedName" : _localizedName
			}));
		}
	}

	if ((self.minimumCount == nil) && (self.maximumCount == nil))
	{
		// A rule without minimum and maximum count has to be considered invalid
		return (OCLocalized(@"Invalid rule without minimum and maximum count"));
	}

	// Validation passed
	return (nil);
}

@end
