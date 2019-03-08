//
//  OCHTTPRequest.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.02.18.
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

#import "OCHTTPRequest.h"
#import "NSURL+OCURLQueryParameterExtensions.h"
#import "OCLogger.h"
#import "NSProgress+OCExtensions.h"
#import "OCMacros.h"

@implementation OCHTTPRequest

@synthesize bodyData = _bodyData;

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		__weak OCHTTPRequest *weakSelf = self;

		_identifier = NSUUID.UUID.UUIDString;

		self.method = OCHTTPMethodGET;
	
		self.headerFields = [NSMutableDictionary new];
		self.parameters = [NSMutableDictionary new];

		NSProgress *progress = [NSProgress indeterminateProgress];
		progress.cancellationHandler = ^{
			[weakSelf cancel];
		};

		self.progress = [[OCProgress alloc] initWithPath:@[OCHTTPRequestGlobalPath, _identifier] progress:progress];

		self.priority = NSURLSessionTaskPriorityDefault;
	}
	
	return(self);
}

- (void)dealloc
{
}

+ (instancetype)requestWithURL:(NSURL *)url
{
	OCHTTPRequest *request = [self new];
	
	request.url = url;

	return (request);
}

#pragma mark - Access
- (NSString *)valueForParameter:(NSString *)parameter
{
	if (parameter == nil) { return(nil); }

	return ([_parameters objectForKey:parameter]);
}

- (void)setValue:(NSString *)value forParameter:(NSString *)parameter
{
	if (parameter == nil) { return; }

	if (value == nil)
	{
		[_parameters removeObjectForKey:parameter];
	}
	else
	{
		[_parameters setObject:value forKey:parameter];
	}
}

- (void)setValueArray:(NSArray *)valueArray apply:(NSString *(^)(id value))applyBlock forParameter:(NSString *)parameter
{
	NSUInteger index = 0;

	if (parameter == nil) { return; }

	if ((valueArray != nil) && (valueArray.count > 0))
	{
		for (id value in valueArray)
		{
			NSString *valueString = nil;

			if (applyBlock != nil)
			{
				valueString = applyBlock(value);
			}

			if (valueString != nil)
			{
				valueString = OCTypedCast(valueString, NSString);
			}

			if (valueString != nil)
			{
				if ((index==0) && (valueArray.count == 1))
				{
					[self setValue:valueString forParameter:parameter];
				}
				else
				{
					[self setValue:valueString forParameter:[NSString stringWithFormat:@"%@[%ld]", parameter, index]];
				}

				index++;
			}
		}
	}
	else
	{
		NSString *parameterArrayPrefix = [parameter stringByAppendingString:@"["];
		NSMutableArray *removeKeys = [NSMutableArray new];

		for (NSString *parameterName in _parameters)
		{
			if (([parameterName hasPrefix:parameterArrayPrefix]) || [parameterName isEqual:parameter])
			{
				[removeKeys addObject:parameterName];
			}
		}

		[_parameters removeObjectsForKeys:removeKeys];
	}
}

- (void)addParameters:(NSDictionary<NSString*,NSString*> *)parameters
{
	if (parameters != nil)
	{
		[_parameters addEntriesFromDictionary:parameters];
	}
}

- (NSString *)valueForHeaderField:(NSString *)headerField
{
	if (headerField == nil) { return(nil); }

	return ([_headerFields objectForKey:headerField]);
}

- (void)setValue:(NSString *)value forHeaderField:(NSString *)headerField
{
	if (headerField == nil) { return; }

	if (value == nil)
	{
		[_headerFields removeObjectForKey:headerField];
	}
	else
	{
		[_headerFields setObject:value forKey:headerField];
	}
}

- (void)addHeaderFields:(NSDictionary<NSString*,NSString*> *)headerFields
{
	if (headerFields != nil)
	{
		[_headerFields addEntriesFromDictionary:headerFields];
	}
}

#pragma mark - Queue scheduling support
- (void)prepareForScheduling
{
	// Handle parameters and set effective URL
	if (_parameters.count > 0)
	{
		if ([_method isEqual:OCHTTPMethodPOST] || [_method isEqual:OCHTTPMethodPUT])
		{
			// POST Method: Generate body from parameters
			NSMutableArray <NSURLQueryItem *> *queryItems = [NSMutableArray array];
			NSURLComponents *urlComponents = [[NSURLComponents alloc] init];
			
			[_parameters enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *value, BOOL * _Nonnull stop) {
				[queryItems addObject:[NSURLQueryItem queryItemWithName:name value:value]];
			}];
			
			urlComponents.queryItems = queryItems;
			
			self.bodyData = [[urlComponents query] dataUsingEncoding:NSUTF8StringEncoding];

			if (_headerFields[@"Content-Type"] == nil)
			{
				[self setValue:@"application/x-www-form-urlencoded" forHeaderField:@"Content-Type"];
			}
		}
		else
		{
			// All other methods: Append parameters to URL
			self.effectiveURL = [_url urlByAppendingQueryParameters:_parameters replaceExisting:YES];
		}
	}
	
	if (self.effectiveURL == nil)
	{
		self.effectiveURL = _url;
	}
}

- (NSMutableURLRequest *)generateURLRequest
{
	NSMutableURLRequest *urlRequest;
	
	if ((urlRequest = [[NSMutableURLRequest alloc] initWithURL:self.effectiveURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60]) != nil)
	{
		// Apply method
		urlRequest.HTTPMethod = self.method;
	
		// Apply header fields
		[_headerFields enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull headerField, NSString * _Nonnull value, BOOL * _Nonnull stop) {
			[urlRequest setValue:value forHTTPHeaderField:headerField];
		}];
		
		// Apply body
		if (_bodyURL != nil)
		{
			if ((_bodyURLInputStream = [[NSInputStream alloc] initWithURL:_bodyURL]) != nil)
			{
				urlRequest.HTTPBodyStream = _bodyURLInputStream;
			}
		}
		else if (self.bodyData != nil)
		{
			urlRequest.HTTPBody = self.bodyData;
		}
	}

	return (urlRequest);
}

- (void)scrubForRescheduling
{
	_httpResponse = nil;

	if (_downloadRequest)
	{
		if (_downloadedFileURL != nil)
		{
			// Delete existing file in download location
			if ([[NSFileManager defaultManager] fileExistsAtPath:_downloadedFileURL.path])
			{
				NSError *error = nil;

				[[NSFileManager defaultManager] removeItemAtURL:_downloadedFileURL error:&error];

				OCLogError(@"Error=%@ deleting downloaded file at %@ for request %@", error, _downloadedFileURL.path, self);
			}
		}
	}

	if (_downloadedFileIsTemporary)
	{
		_downloadedFileURL = nil;
	}
}

#pragma mark - Cancel support
- (void)cancel
{
	@synchronized(self)
	{
		if (!_cancelled)
		{
			self.cancelled = YES;
		}
	}
}

#pragma mark - Description
+ (NSString *)bodyDescriptionForURL:(NSURL *)url data:(NSData *)data headers:(NSDictionary<NSString *, NSString *> *)headers
{
	NSString *contentType = headers[@"Content-Type"];
	BOOL readableContent = [contentType hasPrefix:@"text/"] || [contentType containsString:@"xml"] || [contentType containsString:@"json"] || [contentType isEqualToString:@"application/x-www-form-urlencoded"];

	if (url != nil)
	{
		if (readableContent)
		{
			return ([[NSString alloc] initWithData:[NSData dataWithContentsOfURL:url] encoding:NSUTF8StringEncoding]);
		}

		return ([NSString stringWithFormat:@"[Contents from %@]", url.path]);
	}

	if (data != nil)
	{
		if (readableContent)
		{
			return ([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
		}

		return ([NSString stringWithFormat:@"[%lu bytes of %@ data]", (unsigned long)data.length, contentType]);
	}

	return (nil);
}

+ (NSString *)formattedHeaders:(NSDictionary<NSString *, NSString *> *)headers
{
	NSMutableString *formattedHeaders = [NSMutableString new];

	[headers enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull headerField, NSString * _Nonnull value, BOOL * _Nonnull stop) {
		if ([headerField isEqualToString:@"Authorization"])
		{
			value = @"[redacted]";
		}
		[formattedHeaders appendFormat:@"%@: %@\n", headerField, value];
	}];

	return (formattedHeaders);
}

- (NSString *)requestDescription
{
	NSMutableString *requestDescription = [NSMutableString new];

	NSString *bodyDescription = [OCHTTPRequest bodyDescriptionForURL:_bodyURL data:_bodyData headers:_headerFields];

	[requestDescription appendFormat:@"%@ %@ HTTP/1.1\nHost: %@\n", self.method, self.url.path, self.url.hostAndPort];
	if (_bodyData != nil)
	{
		[requestDescription appendFormat:@"Content-Length: %lu\n", (unsigned long)_bodyData.length];
	}
	if (_bodyURL != nil)
	{
		NSNumber *fileSize = nil;
		if ([_bodyURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL]) {
			[requestDescription appendFormat:@"Content-Length: %lu\n", fileSize.unsignedIntegerValue];
		}
	}
	if (_headerFields.count > 0)
	{
		[requestDescription appendString:[OCHTTPRequest formattedHeaders:self.headerFields]];
	}

	if (bodyDescription != nil)
	{
		[requestDescription appendFormat:@"\n%@\n", bodyDescription];
	}

	return (requestDescription);
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
		NSString *resultHandlerActionString;

		_identifier		= [decoder decodeObjectOfClass:[NSString class] forKey:@"identifier"];

		self.progress		= [decoder decodeObjectOfClass:[OCProgress class] forKey:@"progress"];

		self.url 		= [decoder decodeObjectOfClass:[NSURL class] forKey:@"url"];
		self.effectiveURL 	= [decoder decodeObjectOfClass:[NSURL class] forKey:@"effectiveURL"];
		self.method		= [decoder decodeObjectOfClass:[NSString class] forKey:@"method"];
		self.headerFields 	= [decoder decodeObjectOfClass:[NSMutableDictionary class] forKey:@"headerFields"];
		self.parameters 	= [decoder decodeObjectOfClass:[NSMutableDictionary class] forKey:@"parameters"];
		self.bodyData 		= [decoder decodeObjectOfClass:[NSData class] forKey:@"bodyData"];
		self.bodyURL 		= [decoder decodeObjectOfClass:[NSURL class] forKey:@"bodyURL"];

		self.earliestBeginDate 	= [decoder decodeObjectOfClass:[NSDate class] forKey:@"earliestBeginDate"];
		self.requiredSignals    = [decoder decodeObjectOfClass:[NSSet class] forKey:@"requiredSignals"];

		self.eventTarget 	= [decoder decodeObjectOfClass:[OCEventTarget class] forKey:@"eventTarget"];
		self.userInfo	 	= [decoder decodeObjectOfClass:[NSDictionary class] forKey:@"userInfo"];

		self.priority		= [decoder decodeFloatForKey:@"priority"];
		self.groupID		= [decoder decodeObjectOfClass:[NSString class] forKey:@"groupID"];

		self.downloadRequest	= [decoder decodeBoolForKey:@"downloadRequest"];
		self.downloadedFileURL	= [decoder decodeObjectOfClass:[NSURL class] forKey:@"downloadedFileURL"];
		self.downloadedFileIsTemporary = [decoder decodeBoolForKey:@"downloadedFileIsTemporary"];

		self.isNonCritial 	= [decoder decodeBoolForKey:@"isNonCritial"];
		self.cancelled		= [decoder decodeBoolForKey:@"cancelled"];

		if ((resultHandlerActionString = [decoder decodeObjectOfClass:[NSString class] forKey:@"resultHandlerAction"]) != nil)
		{
			self.resultHandlerAction = NSSelectorFromString(resultHandlerActionString);
		}
	}
	
	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_identifier 	forKey:@"identifier"];

	[coder encodeObject:_progress 		forKey:@"progress"];

	[coder encodeObject:_method 		forKey:@"method"];

	[coder encodeObject:_url 		forKey:@"url"];
	[coder encodeObject:_effectiveURL	forKey:@"effectiveURL"];
	[coder encodeObject:_parameters 	forKey:@"parameters"];
	[coder encodeObject:_headerFields 	forKey:@"headerFields"];
	[coder encodeObject:_bodyData 		forKey:@"bodyData"];
	[coder encodeObject:_bodyURL 		forKey:@"bodyURL"];

	[coder encodeObject:_earliestBeginDate 	forKey:@"earliestBeginDate"];

	[coder encodeObject:_requiredSignals 	forKey:@"requiredSignals"];

	[coder encodeObject:_eventTarget 	forKey:@"eventTarget"];
	[coder encodeObject:_userInfo 		forKey:@"userInfo"];

	[coder encodeFloat:_priority 		forKey:@"priority"];
	[coder encodeObject:_groupID 		forKey:@"groupID"];

	[coder encodeBool:_downloadRequest 	forKey:@"downloadRequest"];
	[coder encodeObject:_downloadedFileURL 	forKey:@"downloadedFileURL"];
	[coder encodeBool:_downloadedFileIsTemporary forKey:@"downloadedFileIsTemporary"];

	[coder encodeBool:_isNonCritial 	forKey:@"isNonCritial"];
	[coder encodeBool:_cancelled 		forKey:@"cancelled"];

	[coder encodeObject:NSStringFromSelector(_resultHandlerAction) forKey:@"resultHandlerAction"];
}

@end

OCHTTPMethod OCHTTPMethodGET = @"GET";
OCHTTPMethod OCHTTPMethodPOST = @"POST";
OCHTTPMethod OCHTTPMethodHEAD = @"HEAD";
OCHTTPMethod OCHTTPMethodPUT = @"PUT";
OCHTTPMethod OCHTTPMethodDELETE = @"DELETE";
OCHTTPMethod OCHTTPMethodMKCOL = @"MKCOL";
OCHTTPMethod OCHTTPMethodOPTIONS = @"OPTIONS";
OCHTTPMethod OCHTTPMethodMOVE = @"MOVE";
OCHTTPMethod OCHTTPMethodCOPY = @"COPY";
OCHTTPMethod OCHTTPMethodPROPFIND = @"PROPFIND";
OCHTTPMethod OCHTTPMethodPROPPATCH = @"PROPPATCH";
OCHTTPMethod OCHTTPMethodLOCK = @"LOCK";
OCHTTPMethod OCHTTPMethodUNLOCK = @"UNLOCK";

OCProgressPathElementIdentifier OCHTTPRequestGlobalPath = @"_httpRequest";
