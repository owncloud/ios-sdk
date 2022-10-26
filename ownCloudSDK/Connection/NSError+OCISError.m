//
//  NSError+OCISError.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 19.09.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "NSError+OCISError.h"
#import "OCMacros.h"

@implementation NSError (OCISError)

+ (nullable NSError *)errorFromOCISErrorDictionary:(NSDictionary<NSString *, NSString *> *)ocisErrorDict underlyingError:(nullable NSError *)underlyingError
{
	NSError *error = nil;

	if ([ocisErrorDict isKindOfClass:NSDictionary.class])
	{
		NSString *ocisCode;

		if ((ocisCode = OCTypedCast(ocisErrorDict[@"code"], NSString)) != nil)
		{
			NSMutableDictionary<NSErrorUserInfoKey, id> *errorUserInfo = [NSMutableDictionary new];
			NSString *message = nil;
			OCError errorCode = OCErrorUnknown;

			errorUserInfo[OCOcisErrorCodeKey] = ocisCode;

			if ((message = OCTypedCast(ocisErrorDict[@"message"], NSString)) != nil)
			{
				errorUserInfo[NSLocalizedDescriptionKey] = message;
			}

			// via https://owncloud.dev/services/app-registry/apps/
			if ([ocisCode isEqual:@"RESOURCE_NOT_FOUND"])
			{
				errorCode = OCErrorResourceNotFound;
			}

			// via https://owncloud.dev/services/app-registry/apps/
			if ([ocisCode isEqual:@"INVALID_PARAMETER"])
			{
				errorCode = OCErrorInvalidParameter;
			}

			if ([ocisCode isEqual:@"TOO_EARLY"])
			{
				errorCode = OCErrorItemProcessing;
			}

			if (underlyingError != nil)
			{
				errorUserInfo[NSUnderlyingErrorKey] = underlyingError;
			}

			error = [NSError errorWithDomain:OCErrorDomain code:errorCode userInfo:errorUserInfo];
		}
	}

	if (error == nil)
	{
		error = underlyingError;
	}

	return (error);
}

@end

NSErrorUserInfoKey OCOcisErrorCodeKey = @"ocisErrorCode";
