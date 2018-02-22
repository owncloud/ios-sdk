//
//  OCConnectionQueue.m
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

#import "OCConnectionQueue.h"

@implementation OCConnectionQueue

@synthesize connection = _connection;
@synthesize maxConcurrentRequests = _maxConcurrentRequests;

- (void)enqueueRequest:(OCConnectionRequest *)request
{
	// Stub implementation
}

- (void)cancelRequest:(OCConnectionRequest *)request
{
	// Stub implementation
}

- (void)cancelRequestsWithGroupID:(OCConnectionRequestGroupID)groupID queuedOnly:(BOOL)queuedOnly
{
	// Stub implementation
}

- (void)handleFinishedRequest:(OCConnectionRequest *)request
{
	// Stub implementation
}


- (void)handleFinishedTask:(NSURLSessionTask *)task
{
	// Stub implementation
}

@end
