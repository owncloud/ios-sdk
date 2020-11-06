//
//  NSError+OCDAVError.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.12.18.
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

#import "NSError+OCDAVError.h"
#import "OCXMLParserNode.h"
#import "OCMacros.h"

static NSErrorUserInfoKey OCDAVErrorExceptionNameKey = @"OCDavErrorExceptionName";
static NSErrorUserInfoKey OCDAVErrorExceptionMessageKey = @"OCDavErrorExceptionMessage";

static NSErrorUserInfoKey OCDAVErrorHeaderNameKey = @"OCDavErrorHeaderName";
static NSErrorUserInfoKey OCDAVErrorHeaderMessageKey = @"OCDavErrorHeaderMessage";

@implementation NSError (OCDAVError)

#pragma mark - OCXMLObjectCreation
+ (NSString *)xmlElementNameForObjectCreation
{
	return (@"d:error");
}

+ (instancetype)instanceFromNode:(OCXMLParserNode *)errorNode xmlParser:(OCXMLParser *)xmlParser
{
	NSError *davError = nil;
	NSString *sabreException;
	NSString *sabreHeader;
	NSString *sabreMessage;

	sabreMessage = errorNode.keyValues[@"s:message"];

	if ((sabreException = errorNode.keyValues[@"s:exception"]) != nil)
	{
		OCDAVError errorCode = OCDAVErrorUnknown;

		// Turn known exceptions into OCDAVError codes
		if ([sabreException isEqual:@"Sabre\\DAV\\Exception\\ServiceUnavailable"])
		{
			errorCode = OCDAVErrorServiceUnavailable;
		}

		if ([sabreException isEqual:@"Sabre\\DAV\\Exception\\NotFound"])
		{
			errorCode = OCDAVErrorNotFound;
		}

		davError = [NSError 	errorWithDomain:OCDAVErrorDomain
				 	code:errorCode
				 	userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
						sabreException, OCDAVErrorExceptionNameKey,
						sabreMessage,   OCDAVErrorExceptionMessageKey,
				 	nil]
			   ];
	}

	if ((sabreHeader = errorNode.keyValues[@"s:header"]) != nil)
	{
		OCDAVError errorCode = OCDAVErrorUnknown;

		// Turn known exceptions into OCDAVError codes
		if ([sabreHeader isEqual:@"If-Match"])
		{
			if ([sabreMessage hasSuffix:@"the resource did not exist"])
			{
				// "An If-Match header was specified and the resource did not exist" when trying to download a file with If-Match header that doesn't exist
				errorCode = OCDAVErrorItemDoesNotExist;
			}
		}

		davError = [NSError 	errorWithDomain:OCDAVErrorDomain
				 	code:errorCode
				 	userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
						sabreException, OCDAVErrorExceptionNameKey,
						sabreMessage,   OCDAVErrorExceptionMessageKey,
				 	nil]
			   ];
	}

	return (davError);
}

#pragma mark - Error message provider
+ (void)load
{
	[self registerOCDAVErrorUserInfoValueProvider];
}

+ (void)registerOCDAVErrorUserInfoValueProvider
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		[NSError setUserInfoValueProviderForDomain:OCDAVErrorDomain provider:^id _Nullable(NSError * _Nonnull err, NSErrorUserInfoKey  _Nonnull userInfoKey) {
			return ([NSError provideUserInfoValueForOCDAVError:err userInfoKey:userInfoKey]);
		}];
	});
}

+ (id)provideUserInfoValueForOCDAVError:(NSError *)error userInfoKey:(NSErrorUserInfoKey)userInfoKey
{
	id value = nil;
	NSString *unlocalizedString = nil;

	if ([userInfoKey isEqualToString:@"NSDescription"] || [userInfoKey isEqualToString:NSLocalizedDescriptionKey])
	{
		switch ((OCDAVError)error.code)
		{
			case OCDAVErrorNone:
				unlocalizedString = @"No DAV error."; // This error should never occur.
			break;

			case OCDAVErrorServiceUnavailable:
				unlocalizedString = @"Server down for maintenance.";
			break;

			case OCDAVErrorNotFound:
				unlocalizedString = @"Resource not found.";
			break;

			case OCDAVErrorUnknown:
				if ((error.davExceptionMessage != nil) && (error.davExceptionName != nil))
				{
					value = [NSString stringWithFormat:@"%@ (%@)", error.davExceptionMessage, error.davExceptionName];
				}
				else if (error.davExceptionMessage != nil)
				{
					value = error.davExceptionMessage;
				}
				else if (error.davExceptionName != nil)
				{
					value = [NSString stringWithFormat:@"(%@)", error.davExceptionName];
				}
			break;

			case OCDAVErrorItemDoesNotExist:
				unlocalizedString = @"Item not found.";
			break;
		}
	}

	if ((value==nil) && (unlocalizedString != nil))
	{
		value = OCLocalizedString(unlocalizedString, nil);
	}

	return (value);
}


#pragma mark - Convenience accessors
- (BOOL)isDAVException
{
	return ([self.domain isEqual:OCDAVErrorDomain]);
}

- (OCDAVError)davError
{
	if ([self.domain isEqual:OCDAVErrorDomain])
	{
		return ((OCDAVError)self.code);
	}

	return (OCDAVErrorNone);
}

- (nullable OCDAVExceptionName)davExceptionName
{
	return (self.userInfo[OCDAVErrorExceptionNameKey]);
}

- (nullable NSString *)davExceptionMessage
{
	return (self.userInfo[OCDAVErrorExceptionMessageKey]);
}

@end

NSErrorDomain OCDAVErrorDomain = @"DAVError";
