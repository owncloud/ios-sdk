//
//  NSError+OCError.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.02.18.
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

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, OCError)
{
	OCErrorInternal, 		//!< Internal error
	OCErrorInsufficientParameters, 	//!< Insufficient parameters

	OCErrorAuthorizationFailed, 		//!< Authorization failed
	OCErrorAuthorizationNoMethodData, 	//!< Authorization failed because no secret data was set for the authentication method
	OCErrorAuthorizationMissingData, 	//!< Authorization failed because data was missing from the secret data for the authentication method
	OCErrroAuthorizationCancelled,		//!< Authorization was cancelled by the user

	OCErrorRequestURLSessionTaskConstructionFailed, //!< Construction of URL Session Task failed
	OCErrorRequestCancelled, 			//!< Request was cancelled
	OCErrorRequestRemovedBeforeScheduling, 		//!< Request was removed before scheduling
	OCErrorRequestCompletedWithError		//!< Request completed with error
};

@interface NSError (OCError)

+ (instancetype)errorWithOCError:(OCError)errorCode;

+ (instancetype)errorWithOCError:(OCError)errorCode userInfo:(NSDictionary<NSErrorUserInfoKey,id> *)userInfo;

@end

#define OCError(errorCode) [NSError errorWithOCError:errorCode userInfo:@{ NSDebugDescriptionErrorKey : [NSString stringWithFormat:@"%s [%@:%d]", __PRETTY_FUNCTION__, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__] }] //!< Macro that creates an OCError from an OCErrorCode, but also adds method name, source file and line number)

#define OCErrorWithInfo(errorCode,errorInfo) [NSError errorWithOCError:errorCode userInfo:@{ NSDebugDescriptionErrorKey : [NSString stringWithFormat:@"%s [%@:%d]", __PRETTY_FUNCTION__, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__], @"OCErrorInfo" : errorInfo }] //!< Like the OCError macro, but allows for an error specific info value

extern NSErrorDomain OCErrorDomain;

