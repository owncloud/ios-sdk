//
//  OCHTTPPipelineTask.h
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

#import <Foundation/Foundation.h>
#import "OCHTTPPipeline.h"
#import "OCHTTPPipelineTaskMetrics.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCHTTPPipelineTask : NSObject
{
	OCHTTPRequest *_request;
	NSData *_requestData;

	OCHTTPResponse *_response;	//!< The response. Lazily deserializes .responseData as needed.
	NSData *_responseData;	//!< The serialized response. Lazily serializes .response as needed.

	NSError *_resultError;	//!< The error with which the request was finished. Lazily deserializes .resultErrorData as needed.
	NSData *_resultErrorData;	//!< The serialized error with which the request was finished. Lazily serialized .resultError as needed.
}

@property(nullable,strong) OCHTTPPipelineTaskID taskID;	//!< The taskID from the backend's database

@property(strong) OCHTTPPipelineID pipelineID;	//!< The ID of the pipeline
@property(strong) NSString *bundleID;		//!< The bundleIdentifier of the originating process

@property(nullable,strong) NSString *urlSessionID;		//!< The sessionIdentifier of the NSURLSession this belongs to (background queues only)
@property(nullable,strong) NSNumber *urlSessionTaskID;		//!< After scheduling: the taskIdentifier of the NSURLSessionTask
@property(nullable,strong) NSURLSessionTask *urlSessionTask; 	//!< After scheduling: the NSURLSessionTask of the request

@property(strong) OCHTTPPipelinePartitionID partitionID;	//!< The paritionID this request belongs to
@property(nullable,strong) OCHTTPRequestGroupID groupID;	//!< The groupID this request belongs to

@property(assign) OCHTTPPipelineTaskState state;		//!< The processing state of the pipeline task

@property(strong,nonatomic) OCHTTPRequestID requestID;			//!< The request's unique requestID

@property(nullable,strong,nonatomic) OCHTTPRequest *request;		//!< The request. Lazily deserializes .requestData as needed.
@property(nullable,strong,nonatomic,readonly) NSData *requestData;	//!< The serialized request. Lazily serializes .request as needed.
@property(assign) BOOL requestFinal;				//!< YES if the request can be scheduled as-is.

@property(nullable,strong,nonatomic) OCHTTPResponse *response;	//!< The response. Lazily deserializes .responseData as needed.
@property(nullable,strong,nonatomic,readonly) NSData *responseData;	//!< The serialized response. Lazily serializes .response as needed.

@property(nullable,strong) OCHTTPPipelineTaskMetrics *metrics; 	//!< (optional) metrics for the task (typically not serialized)

@property(assign) BOOL finished; 				//!< The task has been finished

#pragma mark - Init
- (instancetype)initWithRequest:(OCHTTPRequest *)request pipeline:(OCHTTPPipeline *)pipeline partition:(OCHTTPPipelinePartitionID)partitionID;
- (instancetype)initWithRowDictionary:(NSDictionary<NSString*, id<NSObject>> *)rowDictionary;

- (OCHTTPResponse *)responseFromURLSessionTask:(nullable NSURLSessionTask *)urlSessionTask; //! Creates a blank .response from .request if .response is currently nil. Optionally fills/replaces the .response's httpURLResponse (and thereby status + headerFields) from the urlSessionTask.

@end

extern NSString *OCHTTPPipelineTaskAnyBundleID; //!< Value for OCHTTPPipelineTask.bundleID indicating this task isn't tied to a specific app or extension bundle and can be delivered to attached partition handlers on other processes, too.

NS_ASSUME_NONNULL_END
