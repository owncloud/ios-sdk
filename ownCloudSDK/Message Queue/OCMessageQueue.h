//
//  OCMessageQueue.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.03.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCSyncIssue.h"
#import "OCKeyValueStore.h"
#import "OCBookmark.h"

/*
	Message Queue Concept
	- Queues
		- global queue: for issues occuring outside of a specific core - or that need immediate attention from the user
		- per-core queue: for issues occuring in context of a specific core

	- Handling
		- Sync Engine
			-> sends issue to queue
				- queue
					- checks if issue is already in the queue -> if yes -> return / do nothing
					- packages issue in record
					- sets process' OCProcessSession as record.lockingProcess
					- save record to the queue

				- queue._handleRecord:
					- determines best presenter
						- if any:
							- picks the highest priority one
							- tells the presenter to present the issue
								- waits for completionHandler
									- if didPresent == YES
										-> set record.presentedToUser to YES
										-> if choice provided, handle accordingly and remove issue
									- remove record.lockingProcess
									- save

						- if none:
							- remove record.lockingProcess and save again, allowing other components to take a turn
*/

NS_ASSUME_NONNULL_BEGIN

@class OCMessageQueue;
@class OCMessagePresenter;
@class OCMessage;
@class OCCore;

@protocol OCMessageResponseHandler <NSObject>
- (BOOL)handleResponseToMessage:(OCMessage *)message; //!< Return YES if the response to the message has been handled and the message can be removed from the queue.
@end

@interface OCMessageQueue : NSObject

@property(strong,readonly,nonatomic,class) OCMessageQueue *globalQueue;

@property(strong,readonly) OCKeyValueStore *storage;

@property(strong,nonatomic,readonly) NSArray<OCMessage *> *messages; //!< Messages in the queue

#pragma mark - Init
- (instancetype)initWithStorage:(nullable OCKeyValueStore *)storage;

#pragma mark - Queue
- (void)enqueue:(OCMessage *)message; //!< Adds a message and submits it to handling - takes care of avoiding duplicates based on UUID
- (void)dequeue:(OCMessage *)message; //!< Removes a message from the queue, cancelling presentation if its already presented
- (void)dequeueAllMessagesForBookmarkUUID:(OCBookmarkUUID)bookmarkUUID; //!< Removes all messages from the queue targeted at bookmarkUUID.

#pragma mark - Queue Handling
- (void)setNeedsMessageHandling; //!< Triggers presentation and response handling

#pragma mark - Issue resolution
- (void)resolveIssuesForError:(NSError *)error forBookmarkUUID:(OCBookmarkUUID)bookmarkUUID; //!< Auto-resolves those issue messages where choices can be automatically picked following the resolution of an error
- (void)resolveMessage:(OCMessage *)message withChoice:(OCSyncIssueChoice *)choice; //!< Signals resolution of an issue message with a given choice

#pragma mark - Presentation
- (void)addPresenter:(OCMessagePresenter *)presenter;
- (void)removePresenter:(OCMessagePresenter *)presenter;

#pragma mark - Response handling
- (void)addResponseHandler:(id<OCMessageResponseHandler>)responseHandler; //!< Adds a response handler, but only keeps a weak reference.
- (void)removeResponseHandler:(id<OCMessageResponseHandler>)responseHandler; //!< Removes a response handler.

@end

extern OCKeyValueStoreKey OCKeyValueStoreKeySyncIssueQueue;

NS_ASSUME_NONNULL_END
