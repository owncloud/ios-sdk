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
#import "OCConnection.h"

@implementation OCHTTPRequest

@synthesize bodyData = _bodyData;

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		__weak OCHTTPRequest *weakSelf = self;

		_identifier = NSUUID.UUID.UUIDString;

		_maximumRedirectionDepth = 5;

		self.method = OCHTTPMethodGET;
	
		self.headerFields = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
			// Insert request.identifier as X-Request-ID for tracing and to be able to reidentify the task later
			_identifier, OCHTTPHeaderFieldNameXRequestID,
			_identifier, OCHTTPHeaderFieldNameOriginalRequestID,
		nil];
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

- (OCHTTPRequestStatusPolicy)policyForStatus:(OCHTTPStatusCode)statusCode
{
	OCHTTPRequestStatusPolicy policy = OCHTTPRequestStatusPolicyDefault;

	if (_statusPolicies != nil)
	{
		OCHTTPRequestStatusPolicyNumber policyNumber;

		if ((policyNumber = _statusPolicies[@(statusCode)]) != nil)
		{
			policy = policyNumber.unsignedIntegerValue;
		}
	}

	return (policy);
}

- (void)setPolicy:(OCHTTPRequestStatusPolicy)policy forStatus:(OCHTTPStatusCode)statusCode
{
	if (_statusPolicies == nil)
	{
		_statusPolicies = @{ @(statusCode) : @(policy) };
	}
	else
	{
		_statusPolicies = [[NSMutableDictionary alloc] initWithDictionary:_statusPolicies];
		[(NSMutableDictionary *)_statusPolicies setObject:@(policy) forKey:@(statusCode)];
	}
}

- (NSError *)error
{
	return (_httpResponse.error);
}

- (OCHTTPRequestRedirectPolicy)redirectPolicy
{
	if (_redirectPolicy == OCHTTPRequestRedirectPolicyDefault)
	{
		if (OCTypedCast([OCConnection classSettingForOCClassSettingsKey:OCConnectionTransparentTemporaryRedirect], NSNumber).boolValue)
		{
			return (OCHTTPRequestRedirectPolicyAllowSameHost);
		}
		else
		{
			return (OCHTTPRequestRedirectPolicyValidateConnection);
		}
	}

	return (_redirectPolicy);
}

#pragma mark - Queue scheduling support
- (void)prepareForScheduling
{
	// Handle parameters and set effective URL
	if (_parameters.count > 0)
	{
		if ([_method isEqual:OCHTTPMethodPOST] || [_method isEqual:OCHTTPMethodPUT])
		{
			// POST and PUT methods: generate body from parameters
			NSMutableArray <NSURLQueryItem *> *queryItems = [NSMutableArray array];
			NSURLComponents *urlComponents = [[NSURLComponents alloc] init];
			
			[_parameters enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *value, BOOL * _Nonnull stop) {
				[queryItems addObject:[NSURLQueryItem queryItemWithName:name value:value]];
			}];
			
			urlComponents.queryItems = queryItems;

			// NSURLComponents.percentEncodedQuery will NOT escape "+" as "%2B" because Apple argues that's not what's in the standard and causes issues with normalization
			// (source: http://www.openradar.me/24076063)
			self.bodyData = [[[urlComponents percentEncodedQuery] stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"] dataUsingEncoding:NSUTF8StringEncoding];

			if (_headerFields[OCHTTPHeaderFieldNameContentType] == nil)
			{
				[self setValue:@"application/x-www-form-urlencoded" forHeaderField:OCHTTPHeaderFieldNameContentType];
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

		// Apply settings
		urlRequest.allowsCellularAccess = !self.avoidCellular;
	}

	return (urlRequest);
}

- (void)scrubForRescheduling
{
	_httpResponse = nil;
	_effectiveURL = nil;

	if (_downloadRequest)
	{
		if (_downloadedFileURL != nil)
		{
			// Delete existing file in download location
			if ([[NSFileManager defaultManager] fileExistsAtPath:_downloadedFileURL.path])
			{
				NSError *error = nil;

				[[NSFileManager defaultManager] removeItemAtURL:_downloadedFileURL error:&error];

				OCFileOpLog(@"rm", error, @"Removed downloaded file %@ at %@", OCLogPrivate(self.effectiveURL.absoluteString), _downloadedFileURL.path);

				if (error != nil)
				{
					OCLogError(@"Error=%@ deleting downloaded file at %@ for request %@", error, _downloadedFileURL.path, self);
				}
			}
		}
	}

	if (_downloadedFileIsTemporary)
	{
		_downloadedFileURL = nil;
	}
}

- (OCHTTPRequestID)recreateRequestID
{
	OCHTTPRequestID newID = NSUUID.UUID.UUIDString; // Generate new UUID

	// Update .identifier
	_identifier = newID;

	// Update value in X-Request-ID header
	if ([self valueForHeaderField:OCHTTPHeaderFieldNameXRequestID] != nil)
	{
		[self setValue:newID forHeaderField:OCHTTPHeaderFieldNameXRequestID];
	}

	// Return new ID
	return (newID);
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
+ (NSString *)bodyDescriptionForURL:(NSURL *)url data:(NSData *)data headers:(NSDictionary<NSString *, NSString *> *)headers prefixed:(BOOL)prefixed
{
	NSString *contentType = [[headers[OCHTTPHeaderFieldNameContentType] componentsSeparatedByString:@"; "] firstObject];
	BOOL readableContent = [contentType hasPrefix:@"text/"] ||
			       [contentType isEqualToString:@"application/xml"] ||
			       [contentType isEqualToString:@"application/json"] ||
			       [contentType isEqualToString:@"application/jrd+json"] ||
			       [contentType isEqualToString:@"application/x-www-form-urlencoded"];

	NSString*(^FormatReadableData)(NSData *data) = ^(NSData *data) {
		NSString *readable = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

		if (prefixed && (readable != nil))
		{
			readable = [@"[body] " stringByAppendingString:[readable stringByReplacingOccurrencesOfString:[[NSString alloc] initWithFormat:@"\n"] withString:[[NSString alloc] initWithFormat:@"\n[body] "]]];
		}

		return (readable);
	};

	if (url != nil)
	{
		if (readableContent)
		{
			return (FormatReadableData([NSData dataWithContentsOfURL:url]));
		}

		return ([NSString stringWithFormat:@"%@[Contents from %@]", (prefixed ? @"[body] " : @""), url.path]);
	}

	if (data != nil)
	{
		if (readableContent)
		{
			return (FormatReadableData(data));
		}

		return ([NSString stringWithFormat:@"%@[%lu bytes of %@ data]", (prefixed ? @"[body] " : @""), (unsigned long)data.length, contentType]);
	}

	return (nil);
}

+ (NSString *)formattedHeaders:(NSDictionary<NSString *, NSString *> *)headers withLinePrefix:(NSString *)linePrefix
{
	NSMutableString *formattedHeaders = [NSMutableString new];

	static dispatch_once_t onceToken;
	static NSMutableArray<NSString *> *knownAuthorizationHeaders;

	dispatch_once(&onceToken, ^{
		knownAuthorizationHeaders = [NSMutableArray new];
	});

	[headers enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull headerField, NSString * _Nonnull value, BOOL * _Nonnull stop) {
		if ([headerField isEqualToString:OCHTTPHeaderFieldNameAuthorization])
		{
			NSArray<NSString *> *authorizationComponents = [value componentsSeparatedByString:@" "];
			NSUInteger authHeaderIndex = 0;

			@synchronized (knownAuthorizationHeaders)
			{
				// Do not store copies of header in the cache/memory - use its SHA-1 hash instead
				NSString *hashedAuthorizationHeader = [[[value dataUsingEncoding:NSUTF8StringEncoding] sha1Hash] asHexStringWithSeparator:nil lowercase:YES];

				if (![knownAuthorizationHeaders containsObject:hashedAuthorizationHeader])
				{
					[knownAuthorizationHeaders addObject:hashedAuthorizationHeader];
				}

				authHeaderIndex = [knownAuthorizationHeaders indexOfObject:hashedAuthorizationHeader];
			}

			if (authorizationComponents.count > 1)
			{
				value = [authorizationComponents[0] stringByAppendingFormat:@" [redacted:%lu]", authHeaderIndex];
			}
			else
			{
				value = [NSString stringWithFormat:@"[redacted:%lu]", authHeaderIndex];
			}
		}

		if (linePrefix != nil)
		{
			[formattedHeaders appendFormat:@"%@%@: %@\n", linePrefix, headerField, value];
		}
		else
		{
			[formattedHeaders appendFormat:@"%@: %@\n", headerField, value];
		}
	}];

	return (formattedHeaders);
}

- (NSString *)requestDescriptionPrefixed:(BOOL)prefixed
{
	NSMutableString *requestDescription = [NSMutableString new];
	NSString *infoPrefix = (prefixed ? @"[info] " : @"");
	NSString *headPrefix = (prefixed ? @"[header] " : @"");

	NSString *bodyDescription = [OCHTTPRequest bodyDescriptionForURL:_bodyURL data:_bodyData headers:_headerFields prefixed:prefixed];

	[requestDescription appendFormat:@"%@%@ %@ HTTP/1.1\n%@Host: %@\n", headPrefix, self.method, self.url.path, headPrefix, self.url.hostAndPort];
	if (_autoResume && (_autoResumeInfo != nil))
	{
		[requestDescription appendFormat:@"%@[Auto-Resume: %lu | Info: %@]\n", infoPrefix, (unsigned long)_autoResume, _autoResumeInfo.allKeys];
	}
	if (_avoidCellular)
	{
		[requestDescription appendFormat:@"%@[Avoid Cellular Transfer]\n", infoPrefix];
	}
	if (_redirectPolicy != OCHTTPRequestRedirectPolicyDefault)
	{
		NSString *redirectionPolicy = nil;

		switch (_redirectPolicy)
		{
			case OCHTTPRequestRedirectPolicyDefault:
				redirectionPolicy = @"default";
			break;

			case OCHTTPRequestRedirectPolicyHandleLocally:
				redirectionPolicy = @"handle locally";
			break;

			case OCHTTPRequestRedirectPolicyAllowAnyHost:
				redirectionPolicy = @"any host";
			break;

			case OCHTTPRequestRedirectPolicyAllowSameHost:
				redirectionPolicy = @"same host";
			break;

			case OCHTTPRequestRedirectPolicyValidateConnection:
				redirectionPolicy = @"validate connection";
			break;
		}

		[requestDescription appendFormat:@"%@[Redirect Policy: %@]\n", infoPrefix, redirectionPolicy];
	}
	if (_bodyData != nil)
	{
		[requestDescription appendFormat:@"%@Content-Length: %lu\n", headPrefix, (unsigned long)_bodyData.length];
	}
	if (_bodyURL != nil)
	{
		NSNumber *fileSize = nil;
		if ([_bodyURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL])
		{
			[requestDescription appendFormat:@"%@Content-Length: %lu\n", headPrefix, fileSize.unsignedIntegerValue];
		}
	}
	if (_headerFields.count > 0)
	{
		[requestDescription appendString:[OCHTTPRequest formattedHeaders:self.headerFields withLinePrefix:(prefixed ? headPrefix : nil)]];
	}

	if (bodyDescription != nil)
	{
		[requestDescription appendFormat:@"%@\n%@\n", headPrefix, bodyDescription];
	}

	return (requestDescription);
}

- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p, identifier: %@, method: %@, url: %@, effectiveURL: %@%@%@>", NSStringFromClass(self.class), self, self.identifier, self.method, self.url, self.effectiveURL, ((self.bodyData != nil) ? [NSString stringWithFormat:@", bodyData=%lu bytes", self.bodyData.length] : @""), ((self.bodyURL != nil) ? [NSString stringWithFormat:@", bodyURL=%@", self.bodyURL.absoluteString] : @"")]);
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
		self.headerFields 	= [decoder decodeObjectOfClasses:[[NSSet alloc] initWithObjects:NSMutableDictionary.class, NSString.class, nil] forKey:@"headerFields"];
		self.parameters 	= [decoder decodeObjectOfClasses:[[NSSet alloc] initWithObjects:NSMutableDictionary.class, NSString.class, nil] forKey:@"parameters"];
		self.bodyData 		= [decoder decodeObjectOfClass:[NSData class] forKey:@"bodyData"];
		self.bodyURL 		= [decoder decodeObjectOfClass:[NSURL class] forKey:@"bodyURL"];

		self.authenticationDataID = [decoder decodeObjectOfClass:NSString.class forKey:@"authenticationDataID"];

		self.redirectPolicy	= [decoder decodeIntegerForKey:@"redirectPolicy"];
		self.maximumRedirectionDepth = [decoder decodeIntegerForKey:@"maximumRedirectionDepth"];
		self.redirectionHistory = [decoder decodeObjectOfClasses:[[NSSet alloc] initWithObjects:NSMutableDictionary.class, NSURL.class, nil] forKey:@"redirectionHistory"];

		self.statusPolicies	= [decoder decodeObjectOfClasses:[[NSSet alloc] initWithObjects:NSDictionary.class, NSNumber.class, nil] forKey:@"statusPolicies"];

		self.earliestBeginDate 	= [decoder decodeObjectOfClass:[NSDate class] forKey:@"earliestBeginDate"];

		self.requiredSignals    = [decoder decodeObjectOfClasses:[[NSSet alloc] initWithObjects:NSSet.class, NSString.class, nil] forKey:@"requiredSignals"];
		self.requiredCellularSwitch = [decoder decodeObjectOfClass:[NSString class] forKey:@"requiredCellularSwitch"];

		self.autoResume 	= [decoder decodeBoolForKey:@"autoResume"];
		self.autoResumeInfo	= [decoder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"autoResumeInfo"];

		self.eventTarget 	= [decoder decodeObjectOfClass:[OCEventTarget class] forKey:@"eventTarget"];
		self.userInfo	 	= [decoder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"userInfo"];

		self.priority		= [decoder decodeFloatForKey:@"priority"];
		self.groupID		= [decoder decodeObjectOfClass:[NSString class] forKey:@"groupID"];

		self.downloadRequest	= [decoder decodeBoolForKey:@"downloadRequest"];
		self.downloadedFileURL	= [decoder decodeObjectOfClass:[NSURL class] forKey:@"downloadedFileURL"];
		self.downloadedFileIsTemporary = [decoder decodeBoolForKey:@"downloadedFileIsTemporary"];

		self.avoidCellular	= [decoder decodeBoolForKey:@"avoidCellular"];

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

	[coder encodeObject:_authenticationDataID forKey:@"authenticationDataID"];

	[coder encodeInteger:_redirectPolicy 		forKey:@"redirectPolicy"];
	[coder encodeInteger:_maximumRedirectionDepth 	forKey:@"maximumRedirectionDepth"];
	[coder encodeObject:_redirectionHistory 	forKey:@"redirectionHistory"];

	[coder encodeObject:_statusPolicies	forKey:@"statusPolicies"];

	[coder encodeObject:_earliestBeginDate 	forKey:@"earliestBeginDate"];

	[coder encodeObject:_requiredSignals 		forKey:@"requiredSignals"];
	[coder encodeObject:_requiredCellularSwitch 	forKey:@"requiredCellularSwitch"];

	[coder encodeBool:_autoResume 		forKey:@"autoResume"];
	[coder encodeObject:_autoResumeInfo	forKey:@"autoResumeInfo"];

	[coder encodeObject:_eventTarget 	forKey:@"eventTarget"];
	[coder encodeObject:_userInfo 		forKey:@"userInfo"];

	[coder encodeFloat:_priority 		forKey:@"priority"];
	[coder encodeObject:_groupID 		forKey:@"groupID"];

	[coder encodeBool:_downloadRequest 	forKey:@"downloadRequest"];
	[coder encodeObject:_downloadedFileURL 	forKey:@"downloadedFileURL"];
	[coder encodeBool:_downloadedFileIsTemporary forKey:@"downloadedFileIsTemporary"];

	[coder encodeBool:_avoidCellular 	forKey:@"avoidCellular"];

	[coder encodeBool:_isNonCritial 	forKey:@"isNonCritial"];
	[coder encodeBool:_cancelled 		forKey:@"cancelled"];

	[coder encodeObject:NSStringFromSelector(_resultHandlerAction) forKey:@"resultHandlerAction"];
}

@end

OCHTTPMethod OCHTTPMethodGET = @"GET";
OCHTTPMethod OCHTTPMethodPOST = @"POST";
OCHTTPMethod OCHTTPMethodPATCH = @"PATCH";
OCHTTPMethod OCHTTPMethodHEAD = @"HEAD";
OCHTTPMethod OCHTTPMethodPUT = @"PUT";
OCHTTPMethod OCHTTPMethodDELETE = @"DELETE";
OCHTTPMethod OCHTTPMethodMKCOL = @"MKCOL";
OCHTTPMethod OCHTTPMethodOPTIONS = @"OPTIONS";
OCHTTPMethod OCHTTPMethodMOVE = @"MOVE";
OCHTTPMethod OCHTTPMethodCOPY = @"COPY";
OCHTTPMethod OCHTTPMethodPROPFIND = @"PROPFIND";
OCHTTPMethod OCHTTPMethodPROPPATCH = @"PROPPATCH";
OCHTTPMethod OCHTTPMethodREPORT = @"REPORT";
OCHTTPMethod OCHTTPMethodLOCK = @"LOCK";
OCHTTPMethod OCHTTPMethodUNLOCK = @"UNLOCK";

OCHTTPHeaderFieldName OCHTTPHeaderFieldNameLocation = @"Location";
OCHTTPHeaderFieldName OCHTTPHeaderFieldNameAuthorization = @"Authorization";
OCHTTPHeaderFieldName OCHTTPHeaderFieldNameXRequestID = @"X-Request-ID";
OCHTTPHeaderFieldName OCHTTPHeaderFieldNameOriginalRequestID = @"Original-Request-ID";
OCHTTPHeaderFieldName OCHTTPHeaderFieldNameContentType = @"Content-Type";
OCHTTPHeaderFieldName OCHTTPHeaderFieldNameContentLength = @"Content-Length";
OCHTTPHeaderFieldName OCHTTPHeaderFieldNameDepth = @"Depth";
OCHTTPHeaderFieldName OCHTTPHeaderFieldNameDestination = @"Destination";
OCHTTPHeaderFieldName OCHTTPHeaderFieldNameOverwrite = @"Overwrite";
OCHTTPHeaderFieldName OCHTTPHeaderFieldNameIfMatch = @"If-Match";
OCHTTPHeaderFieldName OCHTTPHeaderFieldNameIfNoneMatch = @"If-None-Match";
OCHTTPHeaderFieldName OCHTTPHeaderFieldNameUserAgent = @"User-Agent";
OCHTTPHeaderFieldName OCHTTPHeaderFieldNameXOCMTime = @"X-OC-MTime";
OCHTTPHeaderFieldName OCHTTPHeaderFieldNameOCChecksum = @"OC-Checksum";
OCHTTPHeaderFieldName OCHTTPHeaderFieldNameOCConnectionValidator = @"OC-Connection-Validator";

OCProgressPathElementIdentifier OCHTTPRequestGlobalPath = @"_httpRequest";

OCHTTPRequestResumeInfoKey OCHTTPRequestResumeInfoKeySystemResumeData = @"_systemResumeData";

