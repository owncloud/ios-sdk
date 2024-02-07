//
//  OCPasswordPolicy+Generator.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.02.24.
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

#import "OCPasswordPolicy+Generator.h"

@implementation OCPasswordPolicy (Generator)

/*
	Password Generator Algorithm

	Base assumptions:
	- random numbers are generated via a cryptographically secure random number generator
	- limit the ability of an attacker to make assumptions by using randomness whenever possible - including the length

	Methodology:
	- determine the number of characters to generate. If a range is provided, pick a random number of characters within that range.
	- for each rule, generate the minimum number of characters required for the rule, picking characters randomly from the valid characters of the respective rule
	- fill up the remaining empty space with randomly picked characters of randomly picked rules that have not yet reached their maximum count (if any)
	- with all generated characters collected in an array, use a loop with $passwordLength iterations, randomly picking an offset in each iteration, then removing that character from the array, building the final password by appending it to the end of the result string
 */

- (NSString *)generatePasswordWithMinLength:(NSNumber *)minLen maxLength:(NSNumber *)maxLen error:(NSError * _Nullable __autoreleasing *)error
{
	__block OSStatus randomError = errSecSuccess;

	// Random number generator, using kSecRandomDefault (described as "cryptographically secure random number generator" in the header)
	UInt8 (^Random)(UInt8 maxValue) = ^(UInt8 divisor){
		UInt8 randomByte;
		int err;

		if (divisor == 0) { return((UInt8) 0); } // Avoid division by zero

		if ((err = SecRandomCopyBytes(kSecRandomDefault, 1, (void *)&randomByte)) != errSecSuccess) {
			randomError = err;
		}

		return (UInt8)(randomByte % divisor);
	};

	NSString * _Nullable (^RandomChar)(OCPasswordPolicyRule *rule) = ^(OCPasswordPolicyRule *rule) {
		NSString *validCharacters;

		if ((validCharacters = rule.validCharacters) == nil)
		{
			return (validCharacters);
		}

		return ([validCharacters substringWithRange:NSMakeRange(Random(validCharacters.length), 1)]);
	};

	// Determine the number of characters to generate. If a range is provided, pick a random number of characters within that range.
	NSUInteger minLength = minLen.unsignedIntegerValue, maxLength = maxLen.unsignedIntegerValue;

	for (OCPasswordPolicyRule *rule in self.rules)
	{
		if ((rule.validCharactersSet == nil) && (rule.validCharacters == nil))
		{
			if ((rule.minimumCount != nil) && (minLength == 0))
			{
				minLength = rule.minimumCount.unsignedIntegerValue;
			}

			if ((rule.maximumCount != nil) && (maxLength == 0))
			{
				maxLength = rule.maximumCount.unsignedIntegerValue;
			}
		}
	}

	if (minLength == 0) {
		// Error: minimum length couldn't be determined
		if (error != NULL) {
			*error = OCErrorWithDescription(OCErrorInsufficientParameters, @"minimum length couldn't be determined");
		}
		return (nil);
	}

	if ((maxLength != 0) && (minLength > maxLength)) {
		// Error: maximum length exceeds minimum length
		if (error != NULL) {
			*error = OCErrorWithDescription(OCErrorInsufficientParameters, @"maximum length exceeds minimum length");
		}
		return (nil);
	}

	// Generate password
	NSUInteger length = minLength + ((maxLength != 0) ? Random(maxLength-minLength+1) : 0);
	NSString *generatedPassword = nil;
	NSMutableArray<NSString *> *characters = [NSMutableArray new];
	NSMutableArray<OCPasswordPolicyRule *> *remainingRules = [NSMutableArray new];
	NSString *randomChar;

	// - for each rule, generate the minimum number of characters required for the rule, picking characters randomly from the valid characters of the respective rule
	for (OCPasswordPolicyRule *rule in self.rules)
	{
		NSUInteger minCount = rule.minimumCount.unsignedIntegerValue;

		if ((minCount > 0) && (rule.validCharacters.length > 0))
		{
			for (NSUInteger i=0; i<minCount; i++)
			{
				if ((randomChar = RandomChar(rule)) != nil) {
					[characters addObject:randomChar];
				}
			}

			if ((rule.maximumCount == nil) || ((rule.maximumCount != nil) && (minCount < rule.maximumCount.unsignedIntegerValue)))
			{
				// Collect rules where more of its characters are allowed
				[remainingRules addObject:rule];
			}
		}
	}

	// - fill up the remaining empty space with randomly picked characters of randomly picked rules that have not yet reached their maximum count (if any)
	NSInteger remaining = length-characters.count;
	if (remaining > 0)
	{
		for (NSInteger i=0; i<remaining; i++)
		{
			OCPasswordPolicyRule *rule = nil;

			if (remainingRules.count > 0) {
				rule = remainingRules[Random(remainingRules.count)];
			}

			if (rule != nil)
			{
				if ((randomChar = RandomChar(rule)) != nil) {
					[characters addObject:randomChar];
				} else {
					if (error != NULL) {
						*error = OCErrorWithDescription(OCErrorInsufficientParameters, ([@"Error picking character from: " stringByAppendingFormat:@"%@", rule.validCharacters]));
					}
					return (nil);
				}

				if (rule.maximumCount != nil) {
					// Check if maximum character count for this rule is reached
					if ([rule charactersMatchCountIn:[characters componentsJoinedByString:@""]] >= rule.maximumCount.unsignedIntegerValue)
					{
						// Remove rule if it is reached or exceeded
						[remainingRules removeObject:rule];
					}
				}
			}
			else
			{
				// Error: maximum character count reached for all rules - no usable rules remaining
				if (error != NULL) {
					*error = OCErrorWithDescription(OCErrorInsufficientParameters, @"maximum character count reached for all rules - no usable rules remaining");
				}
				return (nil);
			}
		}
	}

	// - with all generated characters collected in an array, use a loop with $passwordLength iterations, randomly picking an offset in each iteration, then removing that character from the array, building the final password by appending it to the end of the result string
	NSMutableArray<NSString *> *reorderedCharacters = [NSMutableArray new];
	NSUInteger characterCount = characters.count;

	for (NSUInteger i=0; i<characterCount; i++)
	{
		NSUInteger pickOffset = Random(characters.count);

		NSString *pickedCharacter = [characters objectAtIndex:pickOffset];
		[characters removeObjectAtIndex:pickOffset];

		[reorderedCharacters addObject:pickedCharacter];
	}

	// Generate password by putting the reordered characters together
	generatedPassword = [reorderedCharacters componentsJoinedByString:@""];

	// Check for random number generator errors
	if (randomError != errSecSuccess) {
		if (error != NULL) {
			*error = [[NSError alloc] initWithDomain:NSOSStatusErrorDomain code:randomError userInfo:nil];
		}
		return (nil);
	}

	// Check for correct length
	if (generatedPassword.length != length) {
		if (error != NULL) {
			*error = OCErrorWithDescription(OCErrorInternal, @"generated password has incorrect length");
		}
		return (nil);
	}

	return (generatedPassword);
}

@end
