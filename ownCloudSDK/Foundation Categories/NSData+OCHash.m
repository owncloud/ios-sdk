//
//  NSData+OCHash.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.02.18.
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

#import "NSData+OCHash.h"
#import <CommonCrypto/CommonCrypto.h>

@implementation NSData (OCHash)

#define CreateAndReturnHashData(digestFunction,digestLength) \
	UInt8 digest[digestLength]; \
	digestFunction(self.bytes, (CC_LONG)self.length, (unsigned char*)&digest); \
	return ([NSData dataWithBytes:&digest length:(NSUInteger)digestLength])

- (NSData *)md5Hash
{
	CreateAndReturnHashData(CC_MD5, CC_MD5_DIGEST_LENGTH);
}

- (NSData *)sha1Hash
{
	CreateAndReturnHashData(CC_SHA1, CC_SHA1_DIGEST_LENGTH);
}

- (NSData *)sha256Hash
{
	CreateAndReturnHashData(CC_SHA256, CC_SHA256_DIGEST_LENGTH);
}

- (NSString *)asHexStringWithSeparator:(NSString *)separator
{
	NSMutableString *hexString = [NSMutableString stringWithCapacity:(self.length * 3)];

	[self enumerateByteRangesUsingBlock:^(const void * _Nonnull bytes, NSRange byteRange, BOOL * _Nonnull stop) {
		UInt8 *p_bytes = (UInt8 *)bytes;

		if (byteRange.location != 0)
		{
			[hexString appendString:separator];
		}
		
		for (NSUInteger idx=0;idx<byteRange.length;idx++)
		{
			[hexString appendFormat:@"%02X", p_bytes[idx]];
		}
	}];
	
	return (hexString);
}

- (NSString *)asFingerPrintString
{
	return ([self asHexStringWithSeparator:@" "]);
}

@end
