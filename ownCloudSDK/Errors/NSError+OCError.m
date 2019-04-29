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

#import <objc/runtime.h>

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
	BOOL forceShortForm = NO;

	if ([userInfoKey isEqualToString:@"NSDescription"] || [userInfoKey isEqualToString:NSLocalizedDescriptionKey])
	{
		NSString *existingLocalization = nil;

		if ((existingLocalization = error.userInfo[NSLocalizedDescriptionKey]) != nil)
		{
			unlocalizedString = existingLocalization;
			forceShortForm = YES;
		}
		else
		{
			switch ((OCError)error.code)
			{
				case OCErrorInternal:
					unlocalizedString = @"Internal error.";
				break;

				case OCErrorInsufficientParameters:
					unlocalizedString = @"Insufficient parameters.";
				break;

				case OCErrorUnknown:
					unlocalizedString = @"Unknown error.";
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

				case OCErrorAuthorizationCancelled:
					unlocalizedString = @"Authorization was cancelled by the user.";
				break;

				case OCErrorRequestURLSessionTaskConstructionFailed:
					unlocalizedString = @"Construction of URL Session Task failed.";
				break;

				case OCErrorNewerVersionExists:
					unlocalizedString = @"A newer version already exists.";
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

				case OCErrorServerNoSupportedAuthMethods:
					unlocalizedString = @"Server doesn't seem to support any authentication method supported by this app.";
				break;

				case OCErrorServerInMaintenanceMode:
					unlocalizedString = @"Server down for maintenance.";
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
					unlocalizedString = @"The action couldn't be performed on the targeted item because the client lacks permissions.";
				break;

				case OCErrorItemOperationForbidden:
					unlocalizedString = @"The operation on the targeted item is not allowed.";
				break;

				case OCErrorItemAlreadyExists:
					unlocalizedString = @"There already is an item at the destination of this action.";
				break;

				case OCErrorItemNotAvailableOffline:
					unlocalizedString = @"Item not available offline.";
				break;

				case OCErrorFileNotFound:
					unlocalizedString = @"File not found.";
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

				case OCErrorSyncRecordNotFound:
					unlocalizedString = @"Sync record not found.";
				break;

				case OCErrorInvalidProcess:
					unlocalizedString = @"Invalid process.";
				break;

				case OCErrorShareUnauthorized:
					unlocalizedString = @"Not authorized to access shares.";
				break;

				case OCErrorShareUnavailable:
					unlocalizedString = @"Shares are unavailable.";
				break;

				case OCErrorShareItemNotADirectory:
					unlocalizedString = @"Item is not a directory.";
				break;

				case OCErrorShareItemNotFound:
					unlocalizedString = @"Item not found.";
				break;

				case OCErrorShareNotFound:
					unlocalizedString = @"Share not found.";
				break;

				case OCErrorShareUnknownType:
					unlocalizedString = @"Unknown share type.";
				break;

				case OCErrorSharePublicUploadDisabled:
					unlocalizedString = @"Public upload was disabled by the administrator.";
				break;

				case OCErrorInsufficientStorage:
					unlocalizedString = @"Insufficient storage.";
				break;
			}
		}
	}
	
	if ((value==nil) && (unlocalizedString != nil))
	{
		if (((error.userInfo.count) > 0 && (!((error.userInfo[NSDebugDescriptionErrorKey]!=nil) && (error.userInfo.count==1)))) && !forceShortForm)
		{
			value = [NSString stringWithFormat:OCLocalizedString(@"%@ (error %ld, %@)", nil), OCLocalizedString(unlocalizedString, nil), (long)error.code, error.userInfo];
		}
		else
		{
			value = [NSString stringWithFormat:OCLocalizedString(@"%@ (error %ld)", nil), OCLocalizedString(unlocalizedString, nil), (long)error.code];
		}
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

- (NSError *)errorByEmbeddingIssue:(OCIssue *)issue
{
	objc_setAssociatedObject(self, (__bridge const void *)OCErrorIssueKey, issue, OBJC_ASSOCIATION_RETAIN);

	return (self);
}

- (OCIssue *)embeddedIssue
{
	return (objc_getAssociatedObject(self, (__bridge const void *)OCErrorIssueKey));
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
