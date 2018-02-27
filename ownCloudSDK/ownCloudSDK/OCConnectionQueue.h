//
//  OCConnectionQueue.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.02.18.
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

#import <Foundation/Foundation.h>
#import "OCConnectionRequest.h"

@class OCConnection;

@interface OCConnectionQueue : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>
{
	__weak OCConnection *_connection;

	NSURLSession *_urlSession;
	
	NSMutableArray<OCConnectionRequest *> *_queuedRequests;

	NSMutableArray<OCConnectionRequest *> *_runningRequests;
	NSMutableSet<OCConnectionRequestGroupID> *_runningRequestsGroupIDs;
	
	NSMutableDictionary<NSNumber*, OCConnectionRequest *> *_runningRequestsByTaskIdentifier;
	
	NSUInteger _maxConcurrentRequests;

	BOOL _authenticatedRequestsCanBeScheduled;

	dispatch_queue_t _actionQueue;
}

@property(weak) OCConnection *connection; //!< The connection this queue belongs to
@property(assign,nonatomic) NSUInteger maxConcurrentRequests; //!< Maximum number of concurrent requests this queue should schedule on the NSURLSession

#pragma mark - Init
- (instancetype)initBackgroundSessionQueueWithIdentifier:(NSString *)identifier connection:(OCConnection *)connection;
- (instancetype)initEphermalQueueWithConnection:(OCConnection *)connection;

#pragma mark - Queue management
- (void)enqueueRequest:(OCConnectionRequest *)request; //!< Adds a request to the queue
- (void)cancelRequest:(OCConnectionRequest *)request; //!< Cancels a request
- (void)cancelRequestsWithGroupID:(OCConnectionRequestGroupID)groupID queuedOnly:(BOOL)queuedOnly; //!< Cancels all requests belonging to a certain group ID. Including running requests if NO is passed for queuedOnly.

#pragma mark - Result handling
- (void)handleFinishedRequest:(OCConnectionRequest *)request error:(NSError *)error; //!< Submits a finished request to handling.

#pragma mark - Request retrieval
- (OCConnectionRequest *)requestForTask:(NSURLSessionTask *)task; //!< Uses the tasks's taskIdentifier to find the running request it belongs to. If the request has been restored (i.e. from a background NSURLSession) and doesn't have a task, the task is re-attached to the request.

@end

#import "OCConnection.h"
