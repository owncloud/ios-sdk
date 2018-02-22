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

@interface OCConnectionQueue : NSObject
{
	__weak OCConnection *connection;

	NSURLSession *_urlSession;
	
	NSMutableArray<OCConnectionRequest *> *_queuedRequests;

	NSMutableArray<OCConnectionRequest *> *_runningRequests;
	NSMutableSet<OCConnectionRequestGroupID> *_runningRequestsGroupIDs;
	
	NSUInteger maxConcurrentRequests;
}

@property(weak) OCConnection *connection; //!< The connection this queue belongs to
@property(assign,nonatomic) NSUInteger maxConcurrentRequests; //!< Maximum number of concurrent requests this queue should schedule on the NSURLSession

- (void)enqueueRequest:(OCConnectionRequest *)request; //!< Adds a request to the queue
- (void)cancelRequest:(OCConnectionRequest *)request; //!< Cancels a request
- (void)cancelRequestsWithGroupID:(OCConnectionRequestGroupID)groupID queuedOnly:(BOOL)queuedOnly; //!< Cancels all requests belonging to a certain group ID. Including running requests if NO is passed for queuedOnly.

- (void)handleFinishedRequest:(OCConnectionRequest *)request; //!< Handles a finished request

- (void)handleFinishedTask:(NSURLSessionTask *)task; //!< Uses the task's identifier to re-attach the task to a runningRequest and then proceed to calling -handleFinishedRequest: (used to resume from background NSURLSession task completion)

@end

#import "OCConnection.h"
