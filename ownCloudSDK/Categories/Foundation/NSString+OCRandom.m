//
//  NSString+OCRandom.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.06.19.
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

#import "NSString+OCRandom.h"
#import "NSData+OCRandom.h"
#import "NSData+OCHash.h"
#import "OCLogger.h"

@implementation NSString (OCRandom)

+ (instancetype)stringWithRandomCharactersOfLength:(NSUInteger)length allowedCharacters:(NSString *)allowedCharacters
{
	NSString *returnString = nil;

	if ((length > 0) && (allowedCharacters.length > 1))
	{
		unichar *characters = NULL;

		if ((characters = calloc(length, sizeof(unichar))) != NULL)
		{
			NSString *randomHashString = nil;
			NSCharacterSet *allowedCharacterSet = [NSCharacterSet characterSetWithCharactersInString:allowedCharacters];

			size_t charsIdx = 0;

			while ((charsIdx < length) && ((randomHashString = [[NSData dataWithRandomByteCount:length] base64EncodedStringWithOptions:0]) != nil))
			{
				for (NSUInteger idx=0; (idx < randomHashString.length) && (charsIdx < length); idx++)
				{
					unichar character = [randomHashString characterAtIndex:idx];

					if (![allowedCharacterSet characterIsMember:character])
					{
						// Replacement character needed. Use modulo value to determine offset in allowedCharacters
						character = [allowedCharacters characterAtIndex:(character % allowedCharacters.length)];
					}

					characters[charsIdx] = character;
					charsIdx++;
				}
			}

			if (charsIdx == length)
			{
				returnString = [NSString stringWithCharacters:characters length:length];
			}

			free(characters);
		}
		else
		{
			OCLogError(@"Could not allocate memory for random string of length %lu", length);
		}
	}

	return (returnString);
}

@end
