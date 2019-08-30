//
//  OCHTTPPipelineTask.m
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

#import "OCHTTPPipelineTask.h"
#import "OCHTTPResponse.h"
#import "OCMacros.h"

@implementation OCHTTPPipelineTask

@synthesize request = _request;
@synthesize requestData = _requestData;

@synthesize response = _response;
@synthesize responseData = _responseData;

#pragma mark - Init
- (instancetype)initWithRequest:(OCHTTPRequest *)request pipeline:(OCHTTPPipeline *)pipeline partition:(OCHTTPPipelinePartitionID)partitionID
{
	if ((self = [super init]) != nil)
	{
		self.pipelineID = pipeline.identifier;
		self.bundleID = pipeline.bundleIdentifier;

		self.urlSessionID = pipeline.urlSessionIdentifier;

		self.partitionID = partitionID;
		self.groupID = request.groupID;

		self.requestID = request.identifier;

		self.request = request;
	}

	return (self);
}

- (instancetype)initWithRowDictionary:(NSDictionary<NSString *,id<NSObject>> *)rowDictionary
{
	if ((self = [super init]) != nil)
	{
		_taskID = (id _Nonnull)rowDictionary[@"taskID"];

		_pipelineID = (id _Nonnull)rowDictionary[@"pipelineID"];
		_bundleID = (id _Nonnull)rowDictionary[@"bundleID"];

		_urlSessionID = (id _Nullable)OCSQLiteNullResolved(rowDictionary[@"urlSessionID"]);
		_urlSessionTaskID = (id _Nullable)OCSQLiteNullResolved(rowDictionary[@"urlSessionTaskID"]);

		_partitionID = (id _Nonnull)rowDictionary[@"partitionID"];
		_groupID = (id _Nullable)OCSQLiteNullResolved(rowDictionary[@"groupID"]);

		_state = [OCTypedCast(rowDictionary[@"state"], NSNumber) unsignedIntegerValue];

		_requestID = (id _Nonnull)rowDictionary[@"requestID"];
		_requestData = (id _Nonnull)rowDictionary[@"requestData"];
		_requestFinal = [OCTypedCast(rowDictionary[@"requestFinal"], NSNumber) boolValue];

		_responseData = (id _Nullable)OCSQLiteNullResolved(rowDictionary[@"responseData"]);
	}

	return (self);
}

- (OCHTTPResponse *)responseFromURLSessionTask:(NSURLSessionTask *)urlSessionTask
{
	OCHTTPResponse *response = nil;

	// Create a new response if none exists
	if ((response = self.response) == nil)
	{
		response = [[OCHTTPResponse alloc] initWithRequest:self.request HTTPError:nil];
		self.response = response;
	}

	// Fill response with data from NSHTTPURLResponse
	if ((response != nil) && (urlSessionTask != nil))
	{
		NSHTTPURLResponse *httpURLResponse;

		if ((httpURLResponse = OCTypedCast(urlSessionTask.response, NSHTTPURLResponse)) != nil)
		{
			response.httpURLResponse = httpURLResponse; // automatically popuplates headerFields and status
		}
	}

	return ((OCHTTPResponse * _Nonnull)response); // Working around a Static Analyzer bug that assumes [[OCHTTPResponse alloc] init] could return nil and triggers a false positive
}

#pragma mark - Serialized properties
#define RETURN_LAZY_DESERIALIZE(valueVar,dataVar) \
	if (valueVar != nil) \
	{ \
		return (valueVar); \
	} \
	else \
	{ \
		if (dataVar != nil) \
		{ \
			valueVar = [NSKeyedUnarchiver unarchiveObjectWithData:dataVar]; \
		} \
	} \
	return (valueVar)

#define RETURN_LAZY_SERIALIZE(valueVar,dataVar) \
	if (dataVar != nil) \
	{ \
		return (dataVar); \
	} \
	else \
	{ \
		if (valueVar != nil) \
		{ \
			dataVar = [NSKeyedArchiver archivedDataWithRootObject:valueVar]; \
		} \
	} \
	return (dataVar)

#define SET_VALUE(value,valueVar,dataVar) \
		valueVar = value; \
		dataVar = nil

#define SET_DATA(data,dataVar,valueVar) \
		valueVar = nil; \
		dataVar = data


// request & requestData
- (OCHTTPRequest *)request
{
	RETURN_LAZY_DESERIALIZE(_request, _requestData);
}

- (void)setRequest:(OCHTTPRequest *)request
{
	SET_VALUE(request, _request, _requestData);
}

- (NSData *)requestData
{
	RETURN_LAZY_SERIALIZE(_request, _requestData);
}

//- (void)setRequestData:(NSData *)requestData
//{
//	SET_DATA(requestData, _requestData, _request);
//}

// response & responseData
- (OCHTTPResponse *)response
{
	RETURN_LAZY_DESERIALIZE(_response, _responseData);
}

- (void)setResponse:(OCHTTPResponse *)response
{
	SET_VALUE(response, _response, _responseData);
}

- (NSData *)responseData
{
	RETURN_LAZY_SERIALIZE(_response, _responseData);
}

//- (void)setResponseData:(NSData *)responseData
//{
//	SET_DATA(responseData, _responseData, _response);
//}

- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p, taskID: %@, pipelineID: %@, bundleID: %@, urlSessionID: %@, urlSessionTaskID: %@, urlSessionTask: %@, partitionID: %@, groupID: %@, state: %lu, requestID: %@, request: %@, response: %@, metrics: %@, finished: %d>", NSStringFromClass(self.class), self, _taskID, _pipelineID, _bundleID, _urlSessionID, _urlSessionTaskID, _urlSessionTask, _partitionID, _groupID, (unsigned long)_state, _requestID, _request.requestDescription, _response.responseDescription, _metrics, _finished]);
}

@end
