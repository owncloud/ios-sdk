//
//  OCChecksum.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 21.06.18.
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

#import "OCChecksum.h"
#import "OCChecksumAlgorithm.h"
#import "NSError+OCError.h"

@implementation OCChecksum

@synthesize algorithmIdentifier = _algorithmIdentifier;
@synthesize checksum = _checksum;

+ (instancetype)checksumFromHeaderString:(OCChecksumHeaderString)headerString
{
	return ([[self alloc] initFromHeaderString:headerString]);
}

- (instancetype)initFromHeaderString:(OCChecksumHeaderString)headerString
{
	if ((self = [super init]) != nil)
	{
		NSArray <NSString *> *components;

		if ((components = [headerString componentsSeparatedByString:@":"]) != nil)
		{
			if (components.count == 2)
			{
				_algorithmIdentifier = components.firstObject;
				_checksum = components.lastObject;
				_headerString = headerString;
			}
			else
			{
				self = nil;
			}
		}
	}

	return (self);
}

- (instancetype)initWithAlgorithmIdentifier:(OCChecksumAlgorithmIdentifier)algorithmIdentifier checksum:(OCChecksumString)checksum
{
	if ((self = [super init]) != nil)
	{
		_algorithmIdentifier = algorithmIdentifier;
		_checksum = checksum;
	}

	return (self);
}

- (OCChecksumHeaderString)headerString
{
	if (_headerString == nil)
	{
		_headerString = [[NSString alloc] initWithFormat:@"%@:%@", _algorithmIdentifier, _checksum];
	}

	return (_headerString);
}

#pragma mark - Computation
+ (void)computeForFile:(NSURL *)fileURL checksumAlgorithm:(OCChecksumAlgorithmIdentifier)algorithmIdentifier completionHandler:(OCChecksumComputationCompletionHandler)completionHandler
{
	OCChecksumAlgorithm *algorithm;

	if (completionHandler==nil) { return; }

	if ((algorithm = [OCChecksumAlgorithm algorithmForIdentifier:algorithmIdentifier]) != nil)
	{
		[algorithm computeChecksumForFileAtURL:fileURL completionHandler:completionHandler];
	}
	else
	{
		completionHandler(OCError(OCErrorFeatureNotImplemented), nil);
	}
}

- (void)verifyForFile:(NSURL *)fileURL completionHandler:(OCChecksumVerificationCompletionHandler)completionHandler
{
	OCChecksumAlgorithm *algorithm;

	if (completionHandler==nil) { return; }

	if ((algorithm = [OCChecksumAlgorithm algorithmForIdentifier:self.algorithmIdentifier]) != nil)
	{
		[algorithm verifyChecksum:self forFileAtURL:fileURL completionHandler:completionHandler];
	}
	else
	{
		completionHandler(OCError(OCErrorFeatureNotImplemented), NO, nil);
	}
}

#pragma mark - Comparison
- (NSUInteger)hash
{
	return (self.algorithmIdentifier.hash ^ self.checksum.hash);
}

- (BOOL)isEqual:(id)object
{
	OCChecksum *otherChecksum;

	if ((otherChecksum = (OCChecksum *)object) != nil)
	{
		if ([otherChecksum isKindOfClass:[OCChecksum class]])
		{
			if ([_algorithmIdentifier isEqual:otherChecksum.algorithmIdentifier] && [_checksum isEqual:otherChecksum.checksum])
			{
				return (YES);
			}
			else if (([_algorithmIdentifier caseInsensitiveCompare:otherChecksum.algorithmIdentifier]==NSOrderedSame) && ([_checksum caseInsensitiveCompare:otherChecksum.checksum]==NSOrderedSame))
			{
				return (YES);
			}
		}
	}

	return (NO);
}

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		_algorithmIdentifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"algorithmIdentifier"];
		_checksum = [decoder decodeObjectOfClass:[NSString class] forKey:@"checksum"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_algorithmIdentifier forKey:@"algorithmIdentifier"];
	[coder encodeObject:_checksum forKey:@"checksum"];
}

#pragma mark - Description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p, algorithmIdentifier: %@, checksum: %@>", NSStringFromClass(self.class), self, _algorithmIdentifier, _checksum]);
}

@end
