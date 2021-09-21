//
//  OCHTTPTypes.h
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
#import "OCHTTPStatus.h"
#import "OCCertificate.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCHTTPMethod NS_TYPED_ENUM;
typedef NSString* OCHTTPHeaderFieldName NS_TYPED_ENUM;
typedef NSDictionary<OCHTTPHeaderFieldName,NSString*>* OCHTTPStaticHeaderFields;
typedef NSMutableDictionary<OCHTTPHeaderFieldName,NSString*>* OCHTTPHeaderFields;
typedef NSMutableDictionary<NSString*,NSString*>* OCHTTPRequestParameters;

typedef float OCHTTPRequestPriority;
typedef NSString* OCHTTPRequestID;
typedef NSString* OCHTTPRequestGroupID;

typedef NSString* OCHTTPPipelineID;
typedef NSString* OCHTTPPipelinePartitionID;
typedef NSNumber* OCHTTPPipelineTaskID;

typedef NS_ENUM(NSUInteger, OCHTTPPipelineTaskState)
{
	OCHTTPPipelineTaskStatePending,	//!< The task is pending scheduling in the NSURLSession
	OCHTTPPipelineTaskStateRunning, //!< The task is being executed in the NSURLSession
	OCHTTPPipelineTaskStateCompleted //!< The task was returned by the NSURLSession as completed
};

typedef NS_ENUM(NSUInteger, OCHTTPRequestInstruction)
{
	OCHTTPRequestInstructionDeliver,	//!< Deliver the request as usual
	OCHTTPRequestInstructionReschedule	//!< Stop processing of request and reschedule it
};

typedef NSString* OCConnectionSignalID NS_TYPED_ENUM;

@class OCHTTPRequest;
@class OCHTTPResponse;

typedef void(^OCHTTPRequestEphermalResultHandler)(OCHTTPRequest *request, OCHTTPResponse * _Nullable response, NSError * _Nullable error);
typedef void(^OCHTTPRequestEphermalStreamHandler)(OCHTTPRequest *request, OCHTTPResponse * _Nullable response, NSInputStream * _Nullable inputStream, NSError * _Nullable error);
typedef void(^OCConnectionCertificateProceedHandler)(BOOL proceed, NSError * _Nullable error);
typedef void(^OCConnectionEphermalRequestCertificateProceedHandler)(OCHTTPRequest *request, OCCertificate *certificate, OCCertificateValidationResult validationResult, NSError *certificateValidationError, OCConnectionCertificateProceedHandler proceedHandler);

NS_ASSUME_NONNULL_END

#import "OCHTTPRequest.h"
#import "OCHTTPResponse.h"

