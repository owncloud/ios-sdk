//
//  NSData+OCRandom.m
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

#import <Security/Security.h>

#import "NSData+OCRandom.h"
#import "OCLogger.h"

@implementation NSData (OCRandom)

+ (instancetype)dataWithRandomByteCount:(NSUInteger)randomByteCount
{
	NSMutableData *randomBytesData = nil;

	if (randomByteCount > 0)
	{
		if ((randomBytesData = [[NSMutableData alloc] initWithLength:randomByteCount]) != nil)
		{
			int secError;

			if ((secError = SecRandomCopyBytes(kSecRandomDefault, randomByteCount, randomBytesData.mutableBytes)) != errSecSuccess)
			{
				OCLogError(@"Failed to create %lu random bytes with secError=%d", randomByteCount, secError);
				randomBytesData = nil;
			}
		}
		else
		{
			OCLogError(@"Couldn't allocate %lu bytes for random bytes", randomByteCount);
		}
	}

	return (randomBytesData);
}

@end
