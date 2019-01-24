//
//  OCConnectionRequest.m
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

#import "OCConnectionRequest.h"
#import "OCConnectionQueue.h"
#import "NSURL+OCURLQueryParameterExtensions.h"
#import "OCLogger.h"

@implementation OCConnectionRequest

@synthesize urlSessionTask = _urlSessionTask;
@synthesize progress = _progress;

@synthesize urlSessionTaskIdentifier = _urlSessionTaskIdentifier;

@synthesize bookmarkUUID = _bookmarkUUID;

@synthesize method = _method;

@synthesize url = _url;
@synthesize effectiveURL = _effectiveURL;
@synthesize headerFields = _headerFields;
@synthesize parameters = _parameters;
@synthesize bodyData = _bodyData;
@synthesize bodyURL = _bodyURL;

@synthesize earliestBeginDate = _earliestBeginDate;
@synthesize requiredSignals = _requiredSignals;

@synthesize resultHandlerAction = _resultHandlerAction;
@synthesize ephermalResultHandler = _ephermalResultHandler;
@synthesize ephermalRequestCertificateProceedHandler = _ephermalRequestCertificateProceedHandler;
@synthesize forceCertificateDecisionDelegation = _forceCertificateDecisionDelegation;

@synthesize eventTarget = _eventTarget;
@synthesize userInfo = _userInfo;

@synthesize priority = _priority;
@synthesize groupID = _groupID;
@synthesize skipAuthorization = _skipAuthorization;

@synthesize requestObserver = _requestObserver;

@synthesize downloadRequest = _downloadRequest;
@synthesize downloadedFileURL = _downloadedFileURL;

@synthesize responseBodyData = _responseBodyData;

@synthesize cancelled = _cancelled;

@synthesize systemActivity = _systemActivity;

@synthesize error = _error;

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		__weak OCConnectionRequest *weakSelf = self;
		
		self.method = OCConnectionRequestMethodGET;
	
		self.headerFields = [NSMutableDictionary new];
		self.parameters = [NSMutableDictionary new];

		self.progress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
		self.progress.cancellationHandler = ^{
			[weakSelf cancel];
		};

		self.priority = NSURLSessionTaskPriorityDefault;
	}
	
	return(self);
}

- (void)dealloc
{
}

+ (instancetype)requestWithURL:(NSURL *)url
{
	OCConnectionRequest *request = [self new];
	
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

- (void)setPriority:(OCConnectionRequestPriority)priority
{
	_priority = priority;

	if (_urlSessionTask != nil)
	{
		_urlSessionTask.priority = _priority;
	}
}

#pragma mark - Queue scheduling support
- (void)prepareForSchedulingInQueue:(OCConnectionQueue *)queue
{
	// Apply connection's bookmarkUUID
	self.bookmarkUUID = queue.connection.bookmark.uuid;
	
	// Handle parameters and set effective URL
	if (_parameters.count > 0)
	{
		if ([_method isEqual:OCConnectionRequestMethodPOST])
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

- (NSMutableURLRequest *)generateURLRequestForQueue:(OCConnectionQueue *)queue
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
	_responseHTTPStatus = nil;
	_injectedResponse = nil;
	_responseBodyData = nil;
	_responseCertificate = nil;

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

	_urlSessionTask = nil;
	_urlSessionTaskIdentifier = nil;
}

#pragma mark - Cancel support
- (void)cancel
{
	@synchronized(self)
	{
		if (!_cancelled)
		{
			[self willChangeValueForKey:@"cancelled"];

			_cancelled = YES;
			
			if (_urlSessionTask != nil)
			{
				[_urlSessionTask cancel];
			}

			[self didChangeValueForKey:@"cancelled"];
		}
	}
}

#pragma mark - Response Body
- (NSHTTPURLResponse *)response
{
	NSURLResponse *response;

	if (_injectedResponse != nil)
	{
		return (_injectedResponse);
	}
	
	if ((response = _urlSessionTask.response) != nil)
	{
		if ([response isKindOfClass:[NSHTTPURLResponse class]])
		{
			return ((NSHTTPURLResponse *)response);
		}
	}

	return(nil);
}

- (OCHTTPStatus *)responseHTTPStatus
{
	if (_responseHTTPStatus == nil)
	{
		NSHTTPURLResponse *httpResponse;

		if ((httpResponse = self.response) != nil)
		{
			_responseHTTPStatus = [OCHTTPStatus HTTPStatusWithCode:httpResponse.statusCode];
		}
	}

	return (_responseHTTPStatus);
}

- (NSURL *)responseRedirectURL
{
	NSString *locationURLString;
	
	if ((locationURLString = self.response.allHeaderFields[@"Location"]) != nil)
	{
		return ([NSURL URLWithString:locationURLString]);
	}
	
	return (nil);
}

- (void)appendDataToResponseBody:(NSData *)appendResponseBodyData
{
	@synchronized(self)
	{
		if (_responseBodyData == nil)
		{
			_responseBodyData = [[NSMutableData alloc] initWithData:appendResponseBodyData];
		}
		else
		{
			[_responseBodyData appendData:appendResponseBodyData];
		}
	}
}

- (NSStringEncoding)responseBodyEncoding
{
	NSString *textEncodingName;
	NSStringEncoding stringEncoding;

	if ((textEncodingName = self.response.textEncodingName) != nil)
	{
		stringEncoding = CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef)textEncodingName));
	}
	else
	{
		stringEncoding = NSISOLatin1StringEncoding; // ISO-8859-1
	}

	return(stringEncoding);
}

- (NSString *)responseBodyAsString
{
	NSString *responseBodyAsString = nil;
	NSData *responseBodyData;

	if ((responseBodyData = self.responseBodyData) != nil)
	{
		responseBodyAsString = [[NSString alloc] initWithData:responseBodyData encoding:self.responseBodyEncoding];
	}
	
	return (responseBodyAsString);
}

- (NSDictionary *)responseBodyConvertedDictionaryFromJSONWithError:(NSError **)outError
{
	id jsonObject;
	
	if (self.responseBodyData == nil) { return(nil); }
	
	if ((jsonObject = [NSJSONSerialization JSONObjectWithData:self.responseBodyData options:0 error:outError]) != nil)
	{
		if ([jsonObject isKindOfClass:[NSDictionary class]])
		{
			return (jsonObject);
		}
	}
	
	return (nil);
}

- (NSArray *)responseBodyConvertedArrayFromJSONWithError:(NSError **)outError
{
	id jsonObject;

	if (self.responseBodyData == nil) { return(nil); }

	if ((jsonObject = [NSJSONSerialization JSONObjectWithData:self.responseBodyData options:0 error:outError]) != nil)
	{
		if ([jsonObject isKindOfClass:[NSArray class]])
		{
			return (jsonObject);
		}
	}
	
	return (nil);
}

#pragma mark - Description
- (NSString *)_bodyDescriptionForURL:(NSURL *)url data:(NSData *)data headers:(NSDictionary<NSString *, NSString *> *)headers
{
	NSString *contentType = headers[@"Content-Type"];
	BOOL readableContent = [contentType hasPrefix:@"text/"] || [contentType containsString:@"xml"] || [contentType containsString:@"json"];

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

- (NSString *)_formattedHeaders:(NSDictionary<NSString *, NSString *> *)headers
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

	NSString *bodyDescription = [self _bodyDescriptionForURL:_bodyURL data:_bodyData headers:_headerFields];

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
		[requestDescription appendString:[self _formattedHeaders:self.headerFields]];
	}

	if (bodyDescription != nil)
	{
		[requestDescription appendFormat:@"\n%@\n", bodyDescription];
	}

	return (requestDescription);
}

- (NSString *)responseDescription
{
	NSMutableString *responseDescription = [NSMutableString new];

	NSString *bodyDescription = [self _bodyDescriptionForURL:self.downloadedFileURL data:self.responseBodyData headers:self.response.allHeaderFields];

	[responseDescription appendFormat:@"%ld %@\n", (long)self.response.statusCode, [NSHTTPURLResponse localizedStringForStatusCode:self.response.statusCode].uppercaseString];
	if (self.response.allHeaderFields.count > 0)
	{
		[responseDescription appendString:[self _formattedHeaders:self.response.allHeaderFields]];
	}

	if (bodyDescription != nil)
	{
		[responseDescription appendFormat:@"\n%@\n", bodyDescription];
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
		NSString *resultHandlerActionString;

		self.bookmarkUUID	= [decoder decodeObjectOfClass:[NSUUID class] forKey:@"bookmarkUUID"];
		self.urlSessionTaskIdentifier = [decoder decodeObjectOfClass:[NSNumber class] forKey:@"urlSessionTaskIdentifier"];

		self.url 		= [decoder decodeObjectOfClass:[NSURL class] forKey:@"url"];
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

		self.isNonCritial 	= [decoder decodeBoolForKey:@"isNonCritial"];

		if ((resultHandlerActionString = [decoder decodeObjectOfClass:[NSString class] forKey:@"resultHandlerAction"]) != nil)
		{
			self.resultHandlerAction = NSSelectorFromString(resultHandlerActionString);
		}
	}
	
	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_bookmarkUUID	forKey:@"bookmarkUUID"];
	[coder encodeObject:_urlSessionTaskIdentifier forKey:@"urlSessionTaskIdentifier"];

	[coder encodeObject:_url 		forKey:@"url"];
	[coder encodeObject:_method 		forKey:@"method"];
	[coder encodeObject:_headerFields 	forKey:@"headerFields"];
	[coder encodeObject:_parameters 	forKey:@"parameters"];
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

	[coder encodeBool:_isNonCritial 	forKey:@"isNonCritial"];

	[coder encodeObject:NSStringFromSelector(_resultHandlerAction) forKey:@"resultHandlerAction"];
}

@end

OCConnectionRequestMethod OCConnectionRequestMethodGET = @"GET";
OCConnectionRequestMethod OCConnectionRequestMethodPOST = @"POST";
OCConnectionRequestMethod OCConnectionRequestMethodHEAD = @"HEAD";
OCConnectionRequestMethod OCConnectionRequestMethodPUT = @"PUT";
OCConnectionRequestMethod OCConnectionRequestMethodDELETE = @"DELETE";
OCConnectionRequestMethod OCConnectionRequestMethodMKCOL = @"MKCOL";
OCConnectionRequestMethod OCConnectionRequestMethodOPTIONS = @"OPTIONS";
OCConnectionRequestMethod OCConnectionRequestMethodMOVE = @"MOVE";
OCConnectionRequestMethod OCConnectionRequestMethodCOPY = @"COPY";
OCConnectionRequestMethod OCConnectionRequestMethodPROPFIND = @"PROPFIND";
OCConnectionRequestMethod OCConnectionRequestMethodPROPPATCH = @"PROPPATCH";
OCConnectionRequestMethod OCConnectionRequestMethodLOCK = @"LOCK";
OCConnectionRequestMethod OCConnectionRequestMethodUNLOCK = @"UNLOCK";

