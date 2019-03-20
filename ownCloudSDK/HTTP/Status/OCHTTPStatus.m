//
//  OCHTTPStatus.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.02.18.
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

#import "OCHTTPStatus.h"

@implementation OCHTTPStatus

@synthesize code = _code;

+ (instancetype)HTTPStatusWithCode:(OCHTTPStatusCode)code
{
	return ([[self alloc] initWithCode:code]);
}

- (instancetype)initWithCode:(OCHTTPStatusCode)code
{
	if ((self = [super init]) != nil)
	{
		self.code = code;
	}

	return (self);
}

#pragma mark - Convenience accessors
- (BOOL)isSuccess
{
	return ((_code >= 200) && (_code < 300));
}

- (BOOL)isRedirection
{
	return ((_code >= 300) && (_code < 400));
}

- (BOOL)isError
{
	return (_code >= 400);
}

#pragma mark - Error creation
- (NSError *)error
{
	return ([NSError errorWithDomain:OCHTTPStatusErrorDomain code:_code userInfo:nil]);
}

- (NSError *)errorWithURL:(NSURL *)url
{
	return ([NSError errorWithDomain:OCHTTPStatusErrorDomain code:_code userInfo:((url!=nil) ? @{ @"url" : url } : nil)]);
}

- (NSError *)errorWithDescription:(NSString *)description
{
	return ([NSError errorWithDomain:OCHTTPStatusErrorDomain code:_code userInfo:((description!=nil) ? @{ NSLocalizedDescriptionKey : description } : nil)]);
}

- (NSError *)errorWithResponse:(NSHTTPURLResponse *)response
{
	return ([NSError errorWithDomain:OCHTTPStatusErrorDomain code:_code userInfo:((response!=nil) ? @{ @"response" : response } : nil)]);
}

- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p, code: %lu>", NSStringFromClass(self.class), self, (unsigned long)_code]);
}

#pragma mark - Copying
- (id)copyWithZone:(NSZone *)zone
{
	return ([[self class] HTTPStatusWithCode:_code]);
}

#pragma mark - Hash & equality
- (NSUInteger)hash
{
	return ([[self class] hash] ^ _code);
}

- (BOOL)isEqual:(id)object
{
	if ([object isKindOfClass:[self class]])
	{
		return (((OCHTTPStatus *)object).code == _code);
	}

	return (NO);
}

#pragma mark - Secure coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		_code = [decoder decodeIntegerForKey:@"code"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInteger:_code forKey:@"code"];
}

@end

NSErrorDomain OCHTTPStatusErrorDomain = @"OCHTTPStatusErrorDomain";
