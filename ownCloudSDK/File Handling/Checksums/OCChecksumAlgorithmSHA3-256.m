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
#import "NSError+OCChecksum.h"
#import "NSData+OCHash.h"
#import <openssl/evp.h>
#import <openssl/sha.h>

@implementation OCChecksumAlgorithmSHA3

OCChecksumAlgorithmAutoRegister

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
	
	if ((maxLength > 0) && ((readBuffer = calloc(1, maxLength)) != NULL))
	{
		EVP_MD_CTX *mdctx = EVP_MD_CTX_new();
		if (!mdctx) {
			free(readBuffer);
			if (error) {
				*error = [NSError errorWithDomain:OCChecksumErrorDomain code:OCChecksumErrorCodeEVPMDCTXFailed userInfo:@{NSLocalizedDescriptionKey: @"EVP_MD_CTX_new failed"}];
			}
			return nil;
		}
		
		const EVP_MD *md = EVP_sha3_256();
		if (EVP_DigestInit_ex(mdctx, md, NULL) != 1) {
			EVP_MD_CTX_free(mdctx);
			free(readBuffer);
			if (error) {
				*error = [NSError errorWithDomain:OCChecksumErrorDomain code:OCChecksumErrorCodeEVPDIGESTINITEX userInfo:@{NSLocalizedDescriptionKey: @"EVP_DigestInit_ex failed"}];
			}
			return nil;
		}
		
		do
		{
			readLength = [inputStream read:(uint8_t *)readBuffer maxLength:maxLength];
			if (readLength > 0)
			{
				EVP_DigestUpdate(mdctx, readBuffer, (size_t)readLength);
			}
		} while(readLength > 0);
		
		if (readLength == -1)
		{
			if (error != NULL)
			{
				*error = inputStream.streamError;
			}
		}
		else
		{
			unsigned char digest[EVP_MAX_MD_SIZE];
			unsigned int digestLength = 0;
			if (EVP_DigestFinal_ex(mdctx, digest, &digestLength) == 1)
			{
				NSData *digestData = [NSData dataWithBytes:digest length:digestLength];
				checksum = [[OCChecksum alloc] initWithAlgorithmIdentifier:OCChecksumAlgorithmIdentifierSHA3_256 checksum:[digestData asHexStringWithSeparator:nil lowercase:YES]];
			}
			else if (error)
			{
				*error = [NSError errorWithDomain:OCChecksumErrorDomain code:OCChecksumErrorCodeEVPDIGESTINITEX userInfo:@{NSLocalizedDescriptionKey: @"EVP_DigestFinal_ex failed"}];
			}
		}
		
		EVP_MD_CTX_free(mdctx);
		free(readBuffer);
	}
	
	return checksum;
}

@end

OCChecksumAlgorithmIdentifier OCChecksumAlgorithmIdentifierSHA3_256 = @"SHA3-256";
