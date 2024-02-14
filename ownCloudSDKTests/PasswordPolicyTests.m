//
//  PasswordPolicyTests.m
//  ownCloudSDKTests
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

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>

@interface PasswordPolicyTests : XCTestCase

@end

@implementation PasswordPolicyTests

- (void)testRuleMinimum
{
	// Test minimum
	OCPasswordPolicyRule *rule;

	rule = [[OCPasswordPolicyRuleCharacters alloc] initWithCharacters:@"a" characterSet:nil minimumCount:@(1) maximumCount:nil localizedDescription:nil localizedName:@"test"];

	XCTAssert([rule validate:@"a"] == nil);
	XCTAssert([rule validate:@"b"] != nil);

	rule = [[OCPasswordPolicyRuleCharacters alloc] initWithCharacters:@"a" characterSet:nil minimumCount:@(2) maximumCount:nil localizedDescription:nil localizedName:@"test"];

	XCTAssert([rule validate:@"a"] != nil);
	XCTAssert([rule validate:@"aa"] == nil);
	XCTAssert([rule validate:@"b"] != nil);

	rule = [[OCPasswordPolicyRuleCharacters alloc] initWithCharacters:@"abc" characterSet:nil minimumCount:@(2) maximumCount:nil localizedDescription:nil localizedName:@"test"];

	XCTAssert([rule validate:@"a"] != nil);
	XCTAssert([rule validate:@"b"] != nil);
	XCTAssert([rule validate:@"ab"] == nil);
	XCTAssert([rule validate:@"ac"] == nil);
}

- (void)testRuleMaximum
{
	// Test maximum
	OCPasswordPolicyRule *rule;

	rule = [[OCPasswordPolicyRuleCharacters alloc] initWithCharacters:@"a" characterSet:nil minimumCount:nil maximumCount:@(1) localizedDescription:nil localizedName:@"test"];

	XCTAssert([rule validate:@"a"] == nil);
	XCTAssert([rule validate:@"aa"] != nil);
	XCTAssert([rule validate:@"b"] == nil);

	rule = [[OCPasswordPolicyRuleCharacters alloc] initWithCharacters:@"a" characterSet:nil minimumCount:nil maximumCount:@(2) localizedDescription:nil localizedName:@"test"];

	XCTAssert([rule validate:@"a"] == nil);
	XCTAssert([rule validate:@"aa"] == nil);
	XCTAssert([rule validate:@"aaa"] != nil);
	XCTAssert([rule validate:@"b"] == nil);
}

- (void)testRuleInvalid
{
	// Invalid rule without minimum or maximum
	OCPasswordPolicyRule *rule = [[OCPasswordPolicyRuleCharacters alloc] initWithCharacters:@"a" characterSet:nil minimumCount:nil maximumCount:nil localizedDescription:nil localizedName:@"test"];

	XCTAssert([rule validate:@"a"] != nil);
}

- (void)testRuleLowercase
{
	// Test lower-case rules with varying lengths
	OCPasswordPolicyRule *rule;

	rule = [OCPasswordPolicyRule lowercaseCharactersMinimum:@(1) maximum:nil];

	XCTAssert([rule validate:@"A"] != nil);
	XCTAssert([rule validate:@"a"] == nil);
	XCTAssert([rule validate:@"z"] == nil);

	rule = [OCPasswordPolicyRule lowercaseCharactersMinimum:@(2) maximum:nil];

	XCTAssert([rule validate:@"AA"] != nil);
	XCTAssert([rule validate:@"ab"] == nil);
	XCTAssert([rule validate:@"yz"] == nil);

	rule = [OCPasswordPolicyRule lowercaseCharactersMinimum:@(2) maximum:@(2)];

	XCTAssert([rule validate:@"AA"] != nil);
	XCTAssert([rule validate:@"ab"] == nil);
	XCTAssert([rule validate:@"yz"] == nil);
	XCTAssert([rule validate:@"yza"] != nil);
}

- (void)testRuleUppercase
{
	// Test upper-case rules with varying lengths
	OCPasswordPolicyRule *rule;

	rule = [OCPasswordPolicyRule uppercaseCharactersMinimum:@(1) maximum:nil];

	XCTAssert([rule validate:@"a"] != nil);
	XCTAssert([rule validate:@"A"] == nil);
	XCTAssert([rule validate:@"Z"] == nil);

	rule = [OCPasswordPolicyRule uppercaseCharactersMinimum:@(2) maximum:nil];

	XCTAssert([rule validate:@"aa"] != nil);
	XCTAssert([rule validate:@"AB"] == nil);
	XCTAssert([rule validate:@"YZ"] == nil);

	rule = [OCPasswordPolicyRule uppercaseCharactersMinimum:@(2) maximum:@(2)];

	XCTAssert([rule validate:@"aa"] != nil);
	XCTAssert([rule validate:@"AB"] == nil);
	XCTAssert([rule validate:@"YZ"] == nil);
	XCTAssert([rule validate:@"YZA"] != nil);
}

- (void)testRuleDigits
{
	// Test digits rules with varying lengths
	OCPasswordPolicyRule *rule;

	rule = [OCPasswordPolicyRule digitsMinimum:@(1) maximum:nil];

	XCTAssert([rule validate:@"a"] != nil);
	XCTAssert([rule validate:@"1"] == nil);
	XCTAssert([rule validate:@"2"] == nil);

	rule = [OCPasswordPolicyRule digitsMinimum:@(2) maximum:nil];

	XCTAssert([rule validate:@"aa"] != nil);
	XCTAssert([rule validate:@"12"] == nil);
	XCTAssert([rule validate:@"90"] == nil);

	rule = [OCPasswordPolicyRule digitsMinimum:@(2) maximum:@(2)];

	XCTAssert([rule validate:@"aa"] != nil);
	XCTAssert([rule validate:@"12"] == nil);
	XCTAssert([rule validate:@"90"] == nil);
	XCTAssert([rule validate:@"901"] != nil);
}

- (void)testRuleSpecialChars
{
	// Test special chars with varying lengths
	OCPasswordPolicyRule *rule;

	rule = [OCPasswordPolicyRule specialCharacters:@"#!" minimum:@(1)];

	XCTAssert([rule validate:@"a"] != nil);
	XCTAssert([rule validate:@"#"] == nil);
	XCTAssert([rule validate:@"!"] == nil);

	rule = [OCPasswordPolicyRule specialCharacters:@"#!" minimum:@(2)];

	XCTAssert([rule validate:@"a#"] != nil);
	XCTAssert([rule validate:@"#!"] == nil);
	XCTAssert([rule validate:@"!#"] == nil);
}

- (void)testRuleByteLengthMaximum
{
	OCPasswordPolicyRuleByteLength *rule = [[OCPasswordPolicyRuleByteLength alloc] initWithEncoding:NSUTF8StringEncoding maximumByteLength:5];

	// Check with 0 and maximum number of allowed bytes
	XCTAssert([rule validate:@""]==nil);
	XCTAssert([rule validate:@"12345"]==nil);

	// Check with 6 bytes
	NSString *tooLongError = [rule validate:@"123456"];
	NSLog(@"%@", tooLongError);
	XCTAssert(tooLongError!=nil);
}

- (void)testRuleByteLengthConversionError
{
	OCPasswordPolicyRuleByteLength *rule = [[OCPasswordPolicyRuleByteLength alloc] initWithEncoding:NSISOLatin1StringEncoding maximumByteLength:5];

	// Conversion failure
	NSString *nonconvertingCharacters = [rule validate:@"🤯"];
	NSLog(@"%@", nonconvertingCharacters);
	XCTAssert(nonconvertingCharacters!=nil);
}

- (void)testCapabilitiesToPolicyConversion
{
	// Test conversion of capabilities to policy

	/*
		Example excerpt from capabilities:

		{
		  "ocs": {
		    "data": {
		      "capabilities": {
		      	…
			"password_policy": {
			  "min_characters": 8,
			  "max_characters": 72,
			  "min_lowercase_characters": 1,
			  "min_uppercase_characters": 1,
			  "min_digits": 1,
			  "min_special_characters": 1
			},
			…
		      }
		    }
		  }
		}
	*/

	OCCapabilities *capabilities = [[OCCapabilities alloc] initWithRawJSON:@{
		@"ocs" : @{
			@"data" : @{
				@"capabilities" : @{
					@"password_policy" : @{
						@"min_characters" : @(8),
						@"max_characters" : @(12),
						@"min_lowercase_characters" : @(1),
						@"min_uppercase_characters" : @(2),
						@"min_digits" : @(3),
						@"min_special_characters" : @(4)
					}
				}
			}
		}
	}];

	// Test presence of password policy in capabilities
	XCTAssert(capabilities.passwordPolicyEnabled);

	// Generate password policy and test if it applies the rules correctly
	OCPasswordPolicy *policy = capabilities.passwordPolicy;

	XCTAssert(![policy validate:@"1234"].passedValidation);
	XCTAssert(![policy validate:@"12345678"].passedValidation);
	XCTAssert(![policy validate:@"12345678901234"].passedValidation);
	XCTAssert(![policy validate:@"abcdefghijklmn"].passedValidation);
	XCTAssert(![policy validate:@"ABCDEFGHIJKLMN"].passedValidation);
	XCTAssert(![policy validate:@"#!#!#!#!#!#!#!"].passedValidation);
	XCTAssert(![policy validate:@"aBC34#!#!---"].passedValidation);
	XCTAssert( [policy validate:@"aBC345#!#!--"].passedValidation);
	XCTAssert( [policy validate:@"abCD456#!#!-"].passedValidation);

	OCPasswordPolicyReport *report = [policy validate:@""]; // Violate all policies

	for (OCPasswordPolicyRule *rule in report.rules)
	{
		NSString *result;

		if ((result = [report resultForRule:rule]) != nil)
		{
			NSLog(@"Violation: %@", result);
		}

		if ([rule isKindOfClass:OCPasswordPolicyRuleCharacters.class])
		{
			XCTAssert(result != nil, @"Rule did not trigger: %@", rule);
		}
	}
}

- (void)testCapabilitiesWithoutPolicy
{
	// Test absence of password policy in capabilities
	OCCapabilities *capabilities = [[OCCapabilities alloc] initWithRawJSON:@{}];
	XCTAssert(!capabilities.passwordPolicyEnabled);
	XCTAssert(capabilities.passwordPolicy == nil);
}

- (void)testGeneration
{
	OCPasswordPolicy *passwordPolicy = OCPasswordPolicy.defaultPolicy;
	NSError *error = nil;
	NSString *generatedPassword;
	NSUInteger testCount = 1000; // also tested with 1000000
	NSMutableSet<NSString *> *generatedPasswords = [NSMutableSet new];

	for (NSUInteger i=0; i<testCount; i++) {
		if ((generatedPassword = [passwordPolicy generatePasswordWithMinLength:nil maxLength:nil error:&error]) != nil)
		{
			OCPasswordPolicyReport *report = [passwordPolicy validate:generatedPassword];

			if (!report.passedValidation) {
				NSLog(@"%@ didn't pass validation:", generatedPassword);

				for (OCPasswordPolicyRule *rule in report.rules) {
					if (![report passedValidationForRule:rule]) {
						NSLog(@"- %@", [report resultForRule:rule]);
					}
				}
			}

			XCTAssert(report.passedValidation, @"%@ didn't pass validation", generatedPassword);

			XCTAssert(![generatedPasswords containsObject:generatedPassword], @"Duplicate password: %@", generatedPassword);

			[generatedPasswords addObject:generatedPassword];
		}

		XCTAssert(error == nil, @"Error generating password: %@", error);
	}

	XCTAssert(generatedPasswords.count == testCount, @"Only %lu different passwords were generated when %lu different passwords were expected", (unsigned long)generatedPasswords.count, testCount);
}

- (void)testGenerationRandomLength
{
	OCPasswordPolicy *passwordPolicy = OCPasswordPolicy.defaultPolicy;
	NSError *error = nil;
	NSString *generatedPassword;
	NSUInteger testCount = 1000, minLength = 12, maxLength = 20;
	NSMutableSet<NSString *> *generatedPasswords = [NSMutableSet new];
	NSCountedSet<NSNumber *> *generatedPasswordsLengths = [NSCountedSet new];

	for (NSUInteger i=0; i<testCount; i++) {
		if ((generatedPassword = [passwordPolicy generatePasswordWithMinLength:@(minLength) maxLength:@(maxLength) error:&error]) != nil)
		{
			OCPasswordPolicyReport *report = [passwordPolicy validate:generatedPassword];

			if (!report.passedValidation) {
				NSLog(@"%@ didn't pass validation:", generatedPassword);

				for (OCPasswordPolicyRule *rule in report.rules) {
					if (![report passedValidationForRule:rule]) {
						NSLog(@"- %@", [report resultForRule:rule]);
					}
				}
			}

			XCTAssert(report.passedValidation, @"%@ didn't pass validation", generatedPassword);

			XCTAssert(![generatedPasswords containsObject:generatedPassword], @"Duplicate password: %@", generatedPassword);

			[generatedPasswords addObject:generatedPassword];
			[generatedPasswordsLengths addObject:@(generatedPassword.length)];
		}

		XCTAssert(error == nil, @"Error generating password: %@", error);
	}

	NSLog(@"Generated passwords: %@", generatedPasswords);

	NSLog(@"Generated password lengths:");
	for (NSUInteger length = minLength; length <= maxLength; length++)
	{
		NSLog(@"- %lu: %lu x", length, [generatedPasswordsLengths countForObject:@(length)]);

		XCTAssert([generatedPasswordsLengths countForObject:@(length)] > 0, @"No passwords with length %lu generated", length);
	}

	XCTAssert(generatedPasswords.count == testCount, @"Only %lu different passwords were generated when %lu different passwords were expected", (unsigned long)generatedPasswords.count, testCount);
}

- (void)testGenerationWithInvalidParameters
{
	OCPasswordPolicy *passwordPolicy;
	NSError *error = nil;
	NSString *password = nil;

	// Minimum > Maximum
	passwordPolicy = [[OCPasswordPolicy alloc] initWithRules:@[
		[OCPasswordPolicyRule uppercaseCharactersMinimum:@(10) maximum:@(5)]
	]];

	password = [passwordPolicy generatePasswordWithMinLength:nil maxLength:nil error:&error];
	XCTAssert(password == nil);
	XCTAssert(error != nil);

	error = nil;
	password = [passwordPolicy generatePasswordWithMinLength:@(10) maxLength:@(5) error:&error];
	XCTAssert(password == nil);
	XCTAssert(error != nil);

	// Running out of generation rules
	passwordPolicy = [[OCPasswordPolicy alloc] initWithRules:@[
		[OCPasswordPolicyRule uppercaseCharactersMinimum:@(10) maximum:@(11)]
	]];

	password = [passwordPolicy generatePasswordWithMinLength:@(12) maxLength:nil error:&error];
	XCTAssert(password == nil);
	XCTAssert(error != nil);
}

@end
