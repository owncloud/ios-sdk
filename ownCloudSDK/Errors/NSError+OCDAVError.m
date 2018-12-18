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

	if ((sabreException = errorNode.keyValues[@"s:exception"]) != nil)
	{
		OCDAVError errorCode = OCDAVErrorUnknown;
		NSString *sabreMessage;

		sabreMessage = errorNode.keyValues[@"s:message"];

		// Turn known exceptions into OCDAVError codes
		if ([sabreException isEqual:@"Sabre\\DAV\\Exception\\ServiceUnavailable"])
		{
			errorCode = OCDAVErrorServiceUnavailable;
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

			case OCDAVErrorUnknown:
				value = [NSString stringWithFormat:@"%@ (%@)", [error davExceptionMessage], error.davExceptionName];
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
