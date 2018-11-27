//
//  OCChecksumAlgorithmSHA1.m
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

#import <CommonCrypto/CommonCrypto.h>

#import "OCChecksumAlgorithmSHA1.h"
#import "NSData+OCHash.h"

@implementation OCChecksumAlgorithmSHA1

OCChecksumAlgorithmAutoRegister

+ (OCChecksumAlgorithmIdentifier)identifier
{
	return (OCChecksumAlgorithmIdentifierSHA1);
}

- (OCChecksum *)computeChecksumForInputStream:(NSInputStream *)inputStream error:(NSError *__autoreleasing *)error
{
	OCChecksum *checksum = nil;
	NSInteger readLength = 0;
	size_t maxLength = 1 * 1024 * 1024; // 1 MB
	void *readBuffer = NULL;

	if ((readBuffer = malloc(maxLength)) != NULL)
	{
		UInt8 digest[CC_SHA1_DIGEST_LENGTH];
		CC_SHA1_CTX digestContext;

		CC_SHA1_Init(&digestContext);

		do
		{
			if ((readLength = [inputStream read:(uint8_t *)readBuffer maxLength:maxLength]) > 0)
			{
				CC_SHA1_Update(&digestContext, readBuffer, (CC_LONG)readLength);
			}
		} while(readLength > 0);

		CC_SHA1_Final((unsigned char *)&digest, &digestContext);

		if (readLength == -1)
		{
			if (error != NULL)
			{
				*error = inputStream.streamError;
			}
		}
		else
		{
			checksum = [[OCChecksum alloc] initWithAlgorithmIdentifier:OCChecksumAlgorithmIdentifierSHA1 checksum:[[NSData dataWithBytes:digest length:sizeof(digest)] asHexStringWithSeparator:nil lowercase:YES]];
		}

		free(readBuffer);
	}

	return (checksum);
}

@end

OCChecksumAlgorithmIdentifier OCChecksumAlgorithmIdentifierSHA1 = @"SHA1";
