//
//  NSString+OCFilesystemComponent.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.08.26.
//  Copyright © 2026 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2026, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "NSString+OCFilesystemComponent.h"
#import "NSData+OCHash.h"
#import "OCLogger.h"

@implementation NSString (OCFilesystemComponent)

+ (NSRegularExpression *)ocFilesystemCompatibleCharactersRegex
{
	static dispatch_once_t onceToken;
	static NSRegularExpression *_ocFilesystemCompatibleCharactersRegex;
	dispatch_once(&onceToken, ^{
		_ocFilesystemCompatibleCharactersRegex = [[NSRegularExpression alloc] initWithPattern:@"\\A[A-Za-z0-9\\-\\$]+\\z" options:0 error:NULL];
	});

	return(_ocFilesystemCompatibleCharactersRegex);
}

- (BOOL)isValidFilesystemCompatibleComponent
{
	return ([NSString.ocFilesystemCompatibleCharactersRegex numberOfMatchesInString:self options:0 range:NSMakeRange(0, self.length)] == 1);
}

- (nullable NSString *)encodedFilesystemCompatibleComponentIsLossy:(out BOOL * _Nullable)outIsLossy
{
	NSString *encodedPathComponent = nil;
	NSData *stringData = nil;
	const NSUInteger maxPathComponentLength = NAME_MAX;
	BOOL useHashing = NO;

	if (outIsLossy != NULL) { *outIsLossy = NO; }

	if (self.length > maxPathComponentLength)
	{
		// string is too long for use as filesystem component
		useHashing = YES;
	}
	else if (self.isValidFilesystemCompatibleComponent)
	{
		// Matches pattern of typical OC UUID/driveID (example: 166d1210-cdb9-50ab-9f1e-ecb9ef12a304$2e81b56f-9284-409a-9dd0-364604df62ce (73 characters))
		// and doesn't exceed filesystem length limits -> can be used as path component as-is
		encodedPathComponent = self;
	}
	else
	{
		// string contains characters outside the supported set => convert to base64
		useHashing = YES; // use hashing in case conversion to base64 is not feasible

		stringData = [self dataUsingEncoding:NSUTF8StringEncoding];
		if (stringData != nil)
		{
			NSString *base64EncodedString;

			if ((base64EncodedString = [stringData base64EncodedStringWithOptions:0]) != nil)
			{
				// Replace or remove problematic characters
				// (for reference, base64 characters are: A-Z, a-z, "+", "/" and "=" (for padding))
				base64EncodedString = [@"b64," stringByAppendingString:base64EncodedString]; // pre-pend "b64," as a differentiator from directly-usable UUIDs + to make it clear this is a base64-encoded representation
				base64EncodedString = [base64EncodedString stringByReplacingOccurrencesOfString:@"/" withString:@"_"]; // replace "/" (can occur in base64 output) with "_" (can't occur in base64 output, but is used instead of "/" in base64url, so is somewhat standardized)
				base64EncodedString = [base64EncodedString stringByReplacingOccurrencesOfString:@"." withString:@"-"]; // "." should actually never occur in standard base64, but should not be used in path _components_ either, so doing this replacement here for double-extra-abundant-safety, just in case something ever goes wrong with the OS-provided base64..
				base64EncodedString = [base64EncodedString stringByReplacingOccurrencesOfString:@"=" withString:@""];  // remove trailing "=" padding (simply not needed)

				if ((base64EncodedString != nil) &&
				    (base64EncodedString.length <= maxPathComponentLength))
				{
					encodedPathComponent = base64EncodedString;
					useHashing = NO; // conversion to base64 worked => hashing no longer necessary
				}
			}
		}
	}

	if (useHashing)
	{
		// Use SHA-256 hash of string as path component
		//
		// An alternative implementation based on a look-up-table that utilizes the OCVault.keyValueStore to create and maintain a permanent
		// lookup-table that provides (random, then stable) UUIDs as replacements for incoming, problematic strings was considered and
		// implemented but ultimately dismissed, because:
		//
		// a) it could grow indefinitly (possibly to the point of exhausting memory within a File Provider)
		// b) it requires locking (and therefore can have a noticeable performance impact)
		// c) it requires centralized record keeping (vs. reproducable on-the-fly computation with SHA-256) in the KVS (adds complexity)
		// d) the likelyhood of a SHA-256 collission is extremely low (especially when considering in which cases it is actually used here) at 1 : 2^256
		encodedPathComponent = nil;

		if (stringData == nil) {
			stringData = [self dataUsingEncoding:NSUTF8StringEncoding];
		}

		if (stringData != nil)
		{
			encodedPathComponent = [@"s256," stringByAppendingString:[stringData.sha256Hash asHexStringWithSeparator:nil lowercase:YES]]; // prepend "sha256," as a differentiator from directly-usable UUIDs and base64 strings
			if (outIsLossy != NULL) { *outIsLossy = YES; }
		}
	}

	// Check if driveIDPathComponent is non-nil
	if (encodedPathComponent == nil)
	{
		OCLogError(@"Failed to build encodedPathComponent from string \"%@\"", self);
	}

	return (encodedPathComponent);
}

- (nullable NSString *)decodedFilesystemCompatibleComponentIsLossy:(out BOOL * _Nullable)outIsLossy
{
	NSString *decodedString = nil;

	if (outIsLossy != NULL) { *outIsLossy = NO; }

	if ([self hasPrefix:@"b64,"])
	{
		// Base64-encoded UTF8 string
		NSData *decodedData;
		NSString *base64String = [[[self substringFromIndex:4] stringByReplacingOccurrencesOfString:@"_" withString:@"/"] stringByReplacingOccurrencesOfString:@"-" withString:@"."]; // Extract substring and revert replacements

		// Re-apply "=" padding up until reaching the next divisible-by-4 length, so the string can be decoded by NSData
		while (base64String.length % 4) {
			base64String = [base64String stringByAppendingString:@"="];
		};

		if ((decodedData = [[NSData alloc] initWithBase64EncodedString:base64String options:0]) != nil) {
			decodedString = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
		}
	}
	else if ([self hasPrefix:@"s256,"])
	{
		// SHA256 hashed string, needs to be recovered in another way
		if (outIsLossy != NULL) { *outIsLossy = YES; }
	}
	else if (self.isValidFilesystemCompatibleComponent)
	{
		// No known encoding and valid as an OC filesystem component
		decodedString = self;
	}

	return (decodedString);
}

@end
