//
//  OCHTTPTypes.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.02.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCHTTPStatus.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, OCHTTPStorageStatus)
{
	OCHTTPStorageStatusSystemManaged,	//!< Storage is managed by the system (vanishes after delegate/completion call)
	OCHTTPStorageStatusPipelineManaged,	//!< Storage is managed by the pipeline (vanishes when request is removed )
	OCHTTPStorageStatusPartitionManaged	//!< Storage is managed by the partition (no automatic deletion)
};

typedef NSString* OCHTTPMethod NS_TYPED_ENUM;
typedef NSMutableDictionary<NSString*,NSString*>* OCHTTPHeaderFields;
typedef NSMutableDictionary<NSString*,NSString*>* OCHTTPRequestParameters;

typedef float OCHTTPRequestPriority;
typedef NSString* OCHTTPRequestID;
typedef NSString* OCHTTPRequestGroupID;

typedef NSNumber* OCHTTPPipelineTaskID;

typedef NS_ENUM(NSUInteger, OCHTTPPipelineTaskState)
{
	OCHTTPPipelineTaskStatePending,	//!< The task is pending scheduling in the NSURLSession
	OCHTTPPipelineTaskStateRunning, //!< The task is being executed in the NSURLSession
	OCHTTPPipelineTaskStateCompleted //!< The task was returned by the NSURLSession as completed
};

@class OCHTTPRequest;
@class OCHTTPResponse;

NS_ASSUME_NONNULL_END
