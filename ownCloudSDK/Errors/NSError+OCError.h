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
	OCErrorAuthorizationRedirect, 		//!< Authorization failed because the server returned a redirect. Authorization may be successful when retried with the redirect URL. The userInfo of the error contains the alternative server URL as value for the key OCAuthorizationMethodAlternativeServerURLKey
	OCErrorAuthorizationNoMethodData, 	//!< Authorization failed because no secret data was set for the authentication method
	OCErrorAuthorizationMissingData, 	//!< Authorization failed because data was missing from the secret data for the authentication method
	OCErrroAuthorizationCancelled,		//!< Authorization was cancelled by the user

	OCErrorRequestURLSessionTaskConstructionFailed, //!< Construction of URL Session Task failed
	OCErrorRequestCancelled, 			//!< Request was cancelled
	OCErrorRequestRemovedBeforeScheduling, 		//!< Request was removed before scheduling
	OCErrorRequestServerCertificateRejected,	//!< Request was cancelled because the server certificate was rejected
	OCErrorRequestDroppedByURLSession,		//!< Request was dropped by the NSURLSession
	OCErrorRequestCompletedWithError,		//!< Request completed with error
	OCErrorRequestURLSessionInvalidated,		//!< Request couldn't be scheduled because the underlying NSURLSession has been invalidated

	OCErrorException,		//!< An exception occured

	OCErrorResponseUnknownFormat,	//!< Response was in an unknown format
	
	OCErrorServerDetectionFailed,	//!< Server detection failed, i.e. when the server at a URL is not an ownCloud instance
	OCErrorServerTooManyRedirects,	//!< Server detection failed because of too many redirects
	OCErrorServerBadRedirection,	//!< Server redirection to bad/invalid URL
	OCErrorServerVersionNotSupported,    //!< This server version is not supported.
	OCErrorServerNoSupportedAuthMethods, //!< This server doesn't offer any supported auth methods
	OCErrorServerInMaintenanceMode,	//!< Server is in maintenance mode

	OCErrorCertificateInvalid,	//!< The certificate is invalid or contains errors
	OCErrorCertificateMissing,	//!< No certificate was returned for a request despite this being a HTTPS connection (should never occur in production, but only if you forgot to provide a certificate during simulated responses to HTTPS requests)

	OCErrorFeatureNotSupportedForItem,  //!< This feature is not supported for this item.
	OCErrorFeatureNotSupportedByServer, //!< This feature is not supported for this server (version).
	OCErrorFeatureNotImplemented,	    //!< This feature is currently not implemented

	OCErrorItemNotFound, //!< The targeted item has not been found.
	OCErrorItemDestinationNotFound, //!< The destination item has not been found.
	OCErrorItemChanged, //!< The targeted item has changed.
	OCErrorItemInsufficientPermissions, //!< The action couldn't be performed on the targeted item because the client lacks permissions
	OCErrorItemOperationForbidden, //!< The operation on the targeted item is not allowed
	OCErrorItemAlreadyExists, //!< There already is an item at the destination of this action

	OCErrorNewerVersionExists, //!< A newer version already exists

	OCErrorCancelled, //!< The operation was cancelled

	OCErrorOutdatedCache, //!< An operation failed due to outdated cache information

	OCErrorRunningOperation //!< A running operation prevents execution
};

@class OCConnectionIssue;

@interface NSError (OCError)

+ (instancetype)errorWithOCError:(OCError)errorCode;

+ (instancetype)errorWithOCError:(OCError)errorCode userInfo:(NSDictionary<NSErrorUserInfoKey,id> *)userInfo;

- (BOOL)isOCError;

- (BOOL)isOCErrorWithCode:(OCError)errorCode;

- (NSDictionary *)ocErrorInfoDictionary;

#pragma mark - Embedding issues
- (NSError *)errorByEmbeddingIssue:(OCConnectionIssue *)issue;
- (OCConnectionIssue *)embeddedIssue;

@end

#define OCError(errorCode) [NSError errorWithOCError:errorCode userInfo:@{ NSDebugDescriptionErrorKey : [NSString stringWithFormat:@"%s [%@:%d]", __PRETTY_FUNCTION__, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__] }] //!< Macro that creates an OCError from an OCErrorCode, but also adds method name, source file and line number)

#define OCErrorWithInfo(errorCode,errorInfo) [NSError errorWithOCError:errorCode userInfo:@{ NSDebugDescriptionErrorKey : [NSString stringWithFormat:@"%s [%@:%d]", __PRETTY_FUNCTION__, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__], OCErrorInfoKey : errorInfo }] //!< Like the OCError macro, but allows for an error specific info value

#define OCErrorFromError(errorCode,underlyingError) [NSError errorWithOCError:errorCode userInfo:@{ NSDebugDescriptionErrorKey : [NSString stringWithFormat:@"%s [%@:%d]", __PRETTY_FUNCTION__, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__], NSUnderlyingErrorKey : underlyingError }] //!< Like the OCError macro, but allows to specifiy an underlying error, too

extern NSErrorDomain OCErrorDomain;

extern NSString *OCErrorInfoKey;
extern NSString *OCErrorIssueKey;

#define OCFRelease(obj) OCLogDebug(@"CFRelease %s [%@:%d]", __PRETTY_FUNCTION__, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__); CFRelease(obj);
#define OCFRetain(obj) OCLogDebug(@"CFRetain %s [%@:%d]", __PRETTY_FUNCTION__, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__); CFRetain(obj);
