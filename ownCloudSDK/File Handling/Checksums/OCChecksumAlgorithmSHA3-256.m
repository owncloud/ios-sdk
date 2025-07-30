//
//  OCChecksumAlgorithmSHA3-256.m
//  ownCloudSDK
//
//  Created by Matthias Hühne on 29.05.25.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2025, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCChecksumAlgorithmSHA3-256.h"
#import "NSData+OCHash.h"

@import SHA3IUF;

#import "OCExtensionManager.h"
#import "OCExtension+License.h"

@implementation OCChecksumAlgorithmSHA3

+ (void)load
{
	// Register SHA3-256 library license
	// (via https://github.com/brainhub/SHA3IUF/tree/master)
	[[OCExtensionManager sharedExtensionManager] addExtension:[OCExtension licenseExtensionWithIdentifier:@"license.SHA3-256" bundleOfClass:OCChecksumAlgorithmSHA3.class title:@"SHA3IUF" resourceName:@"SHA3IUF" fileExtension:@"LICENSE"]];

	// Register algorithm
	[OCChecksumAlgorithm registerAlgorithmClass:self];
}

+ (OCChecksumAlgorithmIdentifier)identifier
{
    return (OCChecksumAlgorithmIdentifierSHA3_256);
}

- (OCChecksum *)computeChecksumForInputStream:(NSInputStream *)inputStream error:(NSError *__autoreleasing *)error
{
    OCChecksum *checksum = nil;
    NSInteger readLength = 0;
    size_t maxLength = 128 * 1024; // 128 KB
    void *readBuffer = NULL;
    sha3_context ctx;
    unsigned char hash[32];

    if ((maxLength > 0) && ((readBuffer = calloc(1, maxLength)) != NULL)) {
        sha3_Init(&ctx, 256);
        sha3_SetFlags(&ctx, 0);

        do {
            readLength = [inputStream read:(uint8_t *)readBuffer maxLength:maxLength];
            if (readLength > 0) {
                sha3_Update(&ctx, readBuffer, (size_t)readLength);
            }
        } while (readLength > 0);

        if (readLength == -1) {
            if (error != NULL) {
                *error = inputStream.streamError;
            }
        } else {
            const void *digest = sha3_Finalize(&ctx);
            memcpy(hash, digest, 32);
            NSData *digestData = [NSData dataWithBytes:hash length:32];
            checksum = [[OCChecksum alloc] initWithAlgorithmIdentifier:OCChecksumAlgorithmIdentifierSHA3_256 checksum:[digestData asHexStringWithSeparator:nil lowercase:YES]];
        }

        free(readBuffer);
    }
    
    return checksum;
}

@end

OCChecksumAlgorithmIdentifier OCChecksumAlgorithmIdentifierSHA3_256 = @"SHA3-256";
