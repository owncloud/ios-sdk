//
//  OCPasswordPolicyRuleByteLength.m
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

#import "OCPasswordPolicyRuleByteLength.h"
#import "OCMacros.h"
#import "OCLocale.h"
#import "OCLocaleFilterVariables.h"

@implementation OCPasswordPolicyRuleByteLength

- (instancetype)initWithEncoding:(NSStringEncoding)encoding maximumByteLength:(NSInteger)maximumByteLength
{
	if ((self = [super init]) != nil)
	{
		_encoding = encoding;
		_maximumByteLength = maximumByteLength;

		self.localizedDescription = OCLocalizedFormat(@"Less than {{byteLength}} bytes.", @{ @"byteLength" : @(maximumByteLength).stringValue });
	}

	return (self);
}

- (NSString *)nameOfEncoding
{
	CFStringEncoding encoding = CFStringConvertNSStringEncodingToEncoding(self.encoding);

	if (encoding != kCFStringEncodingInvalidId)
	{
		CFStringRef encodingName = CFStringConvertEncodingToIANACharSetName(encoding);

		if (encodingName != NULL)
		{
			return ((__bridge NSString *)encodingName);
		}
	}

	return ([NSString stringWithFormat:@"unknown (%lu)", (unsigned long)self.encoding]);
}

- (NSString *)validate:(NSString *)password
{
	NSUInteger byteLength = [password lengthOfBytesUsingEncoding:self.encoding];

	if ((byteLength == 0) && (password.length > 0))
	{
		// Encoding can't be used to convert the string
		return (OCLocalizedFormat(@"Password can't be converted to {{encoding}}.", @{
			@"encoding" : [self nameOfEncoding]
		}));
	}
	else if (byteLength > self.maximumByteLength)
	{
		// Encoded string would exceed maximum number of bytes
		return (OCLocalizedFormat(@"Longer than {{byteLength}} bytes in {{encoding}} encoding.", (@{
			@"byteLength" : [@(byteLength) stringValue],
			@"encoding" : [self nameOfEncoding]
		})));
	}

	return (nil); // Success
}

@end
