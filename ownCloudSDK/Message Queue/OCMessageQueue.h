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

// # CONCEPT DOC in doc/concepts/MessageQueue.md

NS_ASSUME_NONNULL_BEGIN

@class OCMessageQueue;
@class OCMessagePresenter;
@class OCMessage;
@class OCCore;

@protocol OCMessageResponseHandler <NSObject>
- (BOOL)handleResponseToMessage:(OCMessage *)message; //!< Return YES if the response to the message has been handled and the message can be removed from the queue.
@end

@protocol OCMessageAutoResolver <NSObject>
- (BOOL)autoresolveMessage:(OCMessage *)message; //!< Return YES if the unhandled message was modified (f.ex. with a choice)
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

- (nullable OCMessage *)messageWithUUID:(OCMessageUUID)messageUUID; //!< Retrieves the message with the given UUID

#pragma mark - Queue Handling
- (void)setNeedsMessageHandling; //!< Triggers presentation and response handling

#pragma mark - Issue resolution
- (void)resolveIssuesForError:(NSError *)error forBookmarkUUID:(OCBookmarkUUID)bookmarkUUID; //!< Auto-resolves those issue messages where choices can be automatically picked following the resolution of an error
- (void)resolveMessage:(OCMessage *)message withChoice:(OCMessageChoice *)choice; //!< Signals resolution of an issue message with a given choice

#pragma mark - Presentation
- (void)addPresenter:(OCMessagePresenter *)presenter NS_SWIFT_NAME(add(presenter:));
- (void)removePresenter:(OCMessagePresenter *)presenter  NS_SWIFT_NAME(remove(presenter:));

- (void)present:(OCMessage *)message withPresenter:(OCMessagePresenter *)presenter;

#pragma mark - Auto resolver
- (void)addAutoResolver:(id<OCMessageAutoResolver>)autoResolver NS_SWIFT_NAME(add(autoResolver:)); //!< Adds a response handler, but only keeps a weak reference.
- (void)removeAutoResolver:(id<OCMessageAutoResolver>)autoResolver NS_SWIFT_NAME(remove(autoResolver:)); //!< Removes a response handler.

#pragma mark - Response handling
- (void)addResponseHandler:(id<OCMessageResponseHandler>)responseHandler NS_SWIFT_NAME(add(responseHandler:)); //!< Adds a response handler, but only keeps a weak reference.
- (void)removeResponseHandler:(id<OCMessageResponseHandler>)responseHandler NS_SWIFT_NAME(remove(responseHandler:)); //!< Removes a response handler.

@end

extern OCKeyValueStoreKey OCKeyValueStoreKeySyncIssueQueue;

extern NSNotificationName OCMessageRemovedNotification;

NS_ASSUME_NONNULL_END
