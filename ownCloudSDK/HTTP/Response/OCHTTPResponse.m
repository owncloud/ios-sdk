//
//  OCHTTPResponse.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.02.19.
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

#import "OCHTTPResponse.h"
#import "OCHTTPRequest.h"

@implementation OCHTTPResponse

@synthesize bodyData = _bodyData;

#pragma mark - Init
+ (instancetype)responseWithRequest:(OCHTTPRequest *)request HTTPError:(nullable NSError *)error
{
	return ([[self alloc] initWithRequest:request HTTPError:error]);
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_date = [NSDate new];
	}

	return (self);
}

- (instancetype)initWithRequest:(OCHTTPRequest *)request HTTPError:(nullable NSError *)error
{
	if ((self = [self init]) != nil)
	{
		_requestID = request.identifier;
		_httpError = error;
	}

	return(self);
}

- (void)setHttpURLResponse:(NSHTTPURLResponse *)httpURLResponse
{
	_httpURLResponse = httpURLResponse;

	_status = [[OCHTTPStatus alloc] initWithCode:httpURLResponse.statusCode];
	_headerFields = httpURLResponse.allHeaderFields;
}

#pragma mark - Data receipt
- (void)appendDataToResponseBody:(NSData *)appendResponseBodyData // temporaryFileURL:(NSURL *)temporaryFileURL
{
	@synchronized(self)
	{
		if (_bodyData == nil)
		{
			_bodyData = [[NSMutableData alloc] initWithData:appendResponseBodyData];
		}
		else
		{
			[_bodyData appendData:appendResponseBodyData];
		}
	}
}

- (NSData *)bodyData
{
	@synchronized(self)
	{
		if (_bodyURL != nil)
		{
			if (_mappedBodyData == nil)
			{
				NSError *mappingError = nil;

				_mappedBodyData = [[NSData alloc] initWithContentsOfURL:self.bodyURL options:(NSDataReadingMappedIfSafe|NSDataReadingUncached) error:&mappingError];
			}

			return (_mappedBodyData);
		}
	}

	return (_bodyData);
}

#pragma mark - Convenience accessors
- (NSURL *)redirectURL
{
	NSString *locationURLString;

	if ((locationURLString = self.headerFields[OCHTTPHeaderFieldNameLocation]) != nil)
	{
		return ([[NSURL URLWithString:locationURLString relativeToURL:self.httpURLResponse.URL] absoluteURL]);
	}

	return (nil);
}

- (nullable NSString *)contentType
{
	NSString *contentType;

	if ((contentType = self.headerFields[OCHTTPHeaderFieldNameContentType]) != nil)
	{
		contentType = [contentType componentsSeparatedByString:@";"].firstObject;

		if (contentType.length == 0)
		{
			contentType = nil;
		}
	}

	return (contentType);
}

#pragma mark - Convenience body conversions
- (NSStringEncoding)bodyStringEncoding
{
	NSString *textEncodingName;
	NSStringEncoding stringEncoding;

	if ((textEncodingName = self.httpURLResponse.textEncodingName) != nil)
	{
		stringEncoding = CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef)textEncodingName));
	}
	else
	{
		stringEncoding = NSISOLatin1StringEncoding; // ISO-8859-1
	}

	return(stringEncoding);
}

- (NSString *)bodyAsString
{
	NSString *responseBodyAsString = nil;
	NSData *responseBodyData;

	if ((responseBodyData = self.bodyData) != nil)
	{
		responseBodyAsString = [[NSString alloc] initWithData:responseBodyData encoding:self.bodyStringEncoding];
	}

	return (responseBodyAsString);
}

- (NSDictionary *)bodyConvertedDictionaryFromJSONWithError:(NSError **)outError
{
	id jsonObject;

	if (self.bodyData == nil) { return(nil); }

	if ((jsonObject = [NSJSONSerialization JSONObjectWithData:self.bodyData options:0 error:outError]) != nil)
	{
		if ([jsonObject isKindOfClass:[NSDictionary class]])
		{
			return (jsonObject);
		}
	}

	return (nil);
}

- (NSArray *)bodyConvertedArrayFromJSONWithError:(NSError **)outError
{
	id jsonObject;

	if (self.bodyData == nil) { return(nil); }

	if ((jsonObject = [NSJSONSerialization JSONObjectWithData:self.bodyData options:0 error:outError]) != nil)
	{
		if ([jsonObject isKindOfClass:[NSArray class]])
		{
			return (jsonObject);
		}
	}

	return (nil);
}

- (NSString *)responseDescriptionPrefixed:(BOOL)prefixed
{
	NSMutableString *responseDescription = [NSMutableString new];
	NSString *headPrefix = (prefixed ? @"[header] " : @"");

	NSString *bodyDescription = [OCHTTPRequest bodyDescriptionForURL:_bodyURL data:_bodyData headers:_headerFields prefixed:prefixed];

	[responseDescription appendFormat:@"%@%ld %@\n", headPrefix, (long)_status.code, [NSHTTPURLResponse localizedStringForStatusCode:_status.code].uppercaseString];
	if (_headerFields.count > 0)
	{
		[responseDescription appendString:[OCHTTPRequest formattedHeaders:_headerFields withLinePrefix:(prefixed ? headPrefix : nil)]];
	}

	if (bodyDescription != nil)
	{
		[responseDescription appendFormat:@"%@\n%@\n", headPrefix, bodyDescription];
	}

	return (responseDescription);
}

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		_requestID			= [decoder decodeObjectOfClass:[NSString class] forKey:@"requestID"];

		_date				= [decoder decodeObjectOfClass:[NSString class] forKey:@"date"];

		_certificate 			= [decoder decodeObjectOfClass:[OCCertificate class] forKey:@"certificate"];
		_certificateValidationResult 	= [decoder decodeIntegerForKey:@"certificateValidationResult"];
		_certificateValidationError	= [decoder decodeObjectOfClass:[NSError class] forKey:@"certificateValidationError"];

		_status				= [decoder decodeObjectOfClass:[OCHTTPStatus class] forKey:@"status"];
		_headerFields			= [decoder decodeObjectOfClasses:[[NSSet alloc] initWithObjects:NSDictionary.class, NSString.class, nil] forKey:@"headerFields"];

		_httpURLResponse 		= [decoder decodeObjectOfClass:[NSHTTPURLResponse class] forKey:@"httpURLResponse"];

		_bodyURL			= [decoder decodeObjectOfClass:[NSURL class] forKey:@"bodyURL"];
		_bodyURLIsTemporary		= [decoder decodeBoolForKey:@"bodyURLIsTemporary"];

		_bodyData			= [decoder decodeObjectOfClass:[NSMutableData class] forKey:@"bodyData"];

		_error				= [decoder decodeObjectOfClass:[NSError class] forKey:@"error"];
		_httpError			= [decoder decodeObjectOfClass:[NSError class] forKey:@"httpError"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_requestID 				forKey:@"requestID"];

	[coder encodeObject:_date 				forKey:@"date"];

	[coder encodeObject:_certificate 			forKey:@"certificate"];
	[coder encodeInteger:_certificateValidationResult 	forKey:@"certificateValidationResult"];
	[coder encodeObject:_certificateValidationError 	forKey:@"certificateValidationError"];

	[coder encodeObject:_status 				forKey:@"status"];
	[coder encodeObject:_headerFields			forKey:@"headerFields"];

	[coder encodeObject:_httpURLResponse			forKey:@"httpURLResponse"];

	[coder encodeObject:_bodyURL				forKey:@"bodyURL"];
	[coder encodeBool:_bodyURLIsTemporary 			forKey:@"bodyURLIsTemporary"];

	[coder encodeObject:_bodyData				forKey:@"bodyData"];

	[coder encodeObject:_error				forKey:@"error"];
	[coder encodeObject:_httpError				forKey:@"httpError"];
}


@end
