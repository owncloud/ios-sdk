//
//  NSError+OCError.m
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

#import "NSError+OCError.h"
#import "OCMacros.h"

@implementation NSError (OCError)

+ (void)load
{
	[self registerOCErrorUserInfoValueProvider];
}

+ (void)registerOCErrorUserInfoValueProvider
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		[NSError setUserInfoValueProviderForDomain:OCErrorDomain provider:^id _Nullable(NSError * _Nonnull err, NSErrorUserInfoKey  _Nonnull userInfoKey) {
			return ([NSError provideUserInfoValueForOCError:err userInfoKey:userInfoKey]);
		}];
	});
}

+ (id)provideUserInfoValueForOCError:(NSError *)error userInfoKey:(NSErrorUserInfoKey)userInfoKey
{
	id value = nil;
	NSString *unlocalizedString = nil;

	if ([userInfoKey isEqualToString:@"NSDescription"] || [userInfoKey isEqualToString:NSLocalizedDescriptionKey])
	{
		switch ((OCError)error.code)
		{
			case OCErrorInternal:
				unlocalizedString = @"Internal error.";
			break;

			case OCErrorInsufficientParameters:
				unlocalizedString = @"Insufficient parameters.";
			break;

			case OCErrorAuthorizationFailed:
				unlocalizedString = @"Authorization failed.";
			break;

			case OCErrorAuthorizationRedirect:
				unlocalizedString = @"Authorization failed because the server returned a redirect. Authorization may be successful when retried with the redirect URL.";
			break;

			case OCErrorAuthorizationNoMethodData:
				unlocalizedString = @"Authorization failed because no secret data was set for the authentication method.";
			break;

			case OCErrorAuthorizationMissingData:
				unlocalizedString = @"Authorization failed because data was missing from the secret data for the authentication method.";
			break;

			case OCErrroAuthorizationCancelled:
				unlocalizedString = @"Authorization was cancelled by the user.";
			break;

			case OCErrorRequestURLSessionTaskConstructionFailed:
				unlocalizedString = @"Construction of URL Session Task failed.";
			break;

			case OCErrorRequestCancelled:
				unlocalizedString = @"Request was cancelled.";
			break;

			case OCErrorRequestRemovedBeforeScheduling:
				unlocalizedString = @"Request was removed before scheduling.";
			break;

			case OCErrorRequestServerCertificateRejected:
				unlocalizedString = @"Request was cancelled because the server certificate was rejected.";
			break;

			case OCErrorRequestDroppedByURLSession:
				unlocalizedString = @"Request was dropped by the NSURLSession.";
			break;

			case OCErrorRequestCompletedWithError:
				unlocalizedString = @"Request completed with error.";
			break;

			case OCErrorRequestURLSessionInvalidated:
				unlocalizedString = @"Request couldn't be scheduled because the underlying URL session has been invalidated.";
			break;

			case OCErrorException:
				unlocalizedString = @"An exception occured.";
			break;

			case OCErrorResponseUnknownFormat:
				unlocalizedString = @"Response was in an unknown format.";
			break;

			case OCErrorServerDetectionFailed:
				unlocalizedString = @"Server detection failed, i.e. when the server at a URL is not an ownCloud instance.";
			break;

			case OCErrorServerTooManyRedirects:
				unlocalizedString = @"Server detection failed because of too many redirects.";
			break;

			case OCErrorServerBadRedirection:
				unlocalizedString = @"Server redirection to bad/invalid URL.";
			break;

			case OCErrorServerVersionNotSupported:
				unlocalizedString = @"This server version is not supported.";
			break;

			case OCErrorCertificateInvalid:
				unlocalizedString = @"The certificate is invalid or contains errors";
			break;

			case OCErrorCertificateMissing:
				unlocalizedString = @"No certificate was returned for a request despite this being a HTTPS connection (should never occur in production, but only if you forgot to provide a certificate during simulated responses to HTTPS requests).";
			break;

			case OCErrorFeatureNotSupportedForItem:
				unlocalizedString = @"This feature is not supported for this item.";
			break;

			case OCErrorFeatureNotSupportedByServer:
				unlocalizedString = @"This feature is not supported for this server (version).";
			break;

			case OCErrorFeatureNotImplemented:
				unlocalizedString = @"This feature is currently not implemented";
			break;

			case OCErrorItemNotFound:
				unlocalizedString = @"The targeted item has not been found.";
			break;

			case OCErrorItemDestinationNotFound:
				unlocalizedString = @"The destination item has not been found.";
			break;

			case OCErrorItemChanged:
				unlocalizedString = @"The targeted item has changed.";
			break;

			case OCErrorItemInsufficientPermissions:
				unlocalizedString = @"The action couldn't be performed on the targeted item because the client lacks permisssions.";
			break;

			case OCErrorItemOperationForbidden:
				unlocalizedString = @"The operation on the targeted item is not allowed.";
			break;

			case OCErrorItemAlreadyExists:
				unlocalizedString = @"There already is an item at the destination of this action.";
			break;

			case OCErrorCancelled:
				unlocalizedString = @"The operation was cancelled.";
			break;

			case OCErrorOutdatedCache:
				unlocalizedString = @"An operation failed due to outdated cache information.";
			break;

			case OCErrorRunningOperation:
				unlocalizedString = @"A running operation prevents execution.";
			break;
		}
	}
	
	if ((value==nil) && (unlocalizedString != nil))
	{
		value = [NSString stringWithFormat:@"%@ (error %ld, %@)", OCLocalizedString(unlocalizedString, nil), (long)error.code, error.userInfo];
	}

	return (value);
}

+ (instancetype)errorWithOCError:(OCError)errorCode
{
	return ([NSError errorWithOCError:errorCode userInfo:nil]);
}

+ (instancetype)errorWithOCError:(OCError)errorCode userInfo:(NSDictionary<NSErrorUserInfoKey,id> *)userInfo
{
	return ([NSError errorWithDomain:OCErrorDomain code:errorCode userInfo:userInfo]);
}

- (BOOL)isOCError
{
	return ([self.domain isEqual:OCErrorDomain]);
}

- (BOOL)isOCErrorWithCode:(OCError)errorCode
{
	return ([self.domain isEqual:OCErrorDomain] && (self.code == errorCode));
}

- (NSError *)errorByEmbeddingIssue:(OCConnectionIssue *)issue
{
	NSMutableDictionary *userInfo = nil;
	
	if (issue==nil) { return(self); }
	
	if (self.userInfo != nil)
	{
		userInfo = [NSMutableDictionary dictionaryWithDictionary:self.userInfo];
	}
	else
	{
		userInfo = [NSMutableDictionary dictionary];
	}
	
	userInfo[OCErrorIssueKey] = issue;
	
	return ([NSError errorWithDomain:self.domain code:self.code userInfo:userInfo]);
}

- (OCConnectionIssue *)embeddedIssue
{
	return (self.userInfo[OCErrorIssueKey]);
}

- (NSDictionary *)ocErrorInfoDictionary
{
	NSDictionary *errorInfoDictionary;
	
	if ((errorInfoDictionary = self.userInfo[OCErrorInfoKey]) != nil)
	{
		if ([errorInfoDictionary isKindOfClass:[NSDictionary class]])
		{
			return(errorInfoDictionary);
		}
	}
	
	return (nil);
}

@end

NSErrorDomain OCErrorDomain = @"OCError";

NSString *OCErrorInfoKey = @"OCErrorInfo";
NSString *OCErrorIssueKey = @"OCErrorIssue";
