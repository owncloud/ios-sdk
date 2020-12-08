//
//  OCMessageQueue.m
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

#import "OCMessageQueue.h"
#import "OCCore.h"
#import "OCEvent.h"
#import "OCMessage.h"
#import "OCProcessManager.h"
#import "OCRateLimiter.h"
#import "OCLogger.h"

@interface OCMessageQueue ()
{
	NSMutableArray<OCMessagePresenter *> *_presenters;
	NSHashTable<id<OCMessageResponseHandler>> *_responseHandlers;
	NSHashTable<id<OCMessageAutoResolver>> *_autoResolvers;

	NSMapTable<OCMessageUUID, OCMessagePresenter *> *_activePresenterByMessageUUID;

	NSMutableSet<OCMessageUUID> *_messageUUIDs;

	OCRateLimiter *_observerRateLimiter;

	dispatch_queue_t _workQueue;
}
@end

@implementation OCMessageQueue

+ (OCMessageQueue *)globalQueue
{
	static OCMessageQueue *globalQueue;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{

		NSURL *messageQueueKVSURL = [OCAppIdentity.sharedAppIdentity.appGroupContainerURL URLByAppendingPathComponent:@"messageQueue.dat"];

		OCKeyValueStore *messageStorage = [[OCKeyValueStore alloc] initWithURL:messageQueueKVSURL identifier:@"messageQueue.global"];

		globalQueue = [[OCMessageQueue alloc] initWithStorage:messageStorage];
	});

	return (globalQueue);
}

#pragma mark - Init & Dealloc
- (instancetype)initWithStorage:(nullable OCKeyValueStore *)storage
{
	if ((self = [super init]) != nil)
	{
		_storage = storage;

		_workQueue = dispatch_queue_create("OCMessageQueue work queue", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);

		[_storage registerClasses:[OCEvent.safeClasses setByAddingObjectsFromArray:@[
			OCMessage.class
		]] forKey:OCKeyValueStoreKeySyncIssueQueue];

		_presenters = [NSMutableArray new];
		_responseHandlers = [NSHashTable weakObjectsHashTable];
		_autoResolvers = [NSHashTable weakObjectsHashTable];
		_activePresenterByMessageUUID = [NSMapTable strongToWeakObjectsMapTable];

		_observerRateLimiter = [[OCRateLimiter alloc] initWithMinimumTime:0.1];

		[_storage addObserver:^(OCKeyValueStore *store, OCMessageQueue *owner, OCKeyValueStoreKey key, NSMutableArray<OCMessage *> *messages) {
			[owner setNeedsMessageHandling];
		} forKey:OCKeyValueStoreKeySyncIssueQueue withOwner:self initial:YES];
	}

	return (self);
}

- (void)dealloc
{
	[_storage removeObserverForOwner:self forKey:OCKeyValueStoreKeySyncIssueQueue];
}

#pragma mark - Queue
- (void)enqueue:(OCMessage *)newMessage
{
	if (newMessage == nil) { return; }

	dispatch_sync(self->_workQueue, ^{
		__block OCMessagePresenter *messagePresenter = nil;

		[self.storage updateObjectForKey:OCKeyValueStoreKeySyncIssueQueue usingModifier:^id _Nullable(NSMutableArray<OCMessage *> *existingMessages, BOOL *outDidModify) {
			NSMutableArray<OCMessage *> *messages = existingMessages;
			BOOL isExistingMessage = NO;

			for (OCMessage *message in existingMessages)
			{
				if ([message.uuid isEqual:newMessage.uuid])
				{
					isExistingMessage = YES;
					break;
				}
			}

			if (!isExistingMessage)
			{
				if (messages == nil)
				{
					messages = [NSMutableArray new];
				}

				[messages addObject:newMessage];
				*outDidModify = YES;

				if (!newMessage.presentedToUser)
				{
					if ((messagePresenter = [self presenterForMessage:newMessage addToProcessedBy:YES]) != nil)
					{
						newMessage.lockingProcess = OCProcessManager.sharedProcessManager.processSession;
					}
				}
			}

			self.messages = messages;

			return (messages);
		}];

		if (messagePresenter != nil)
		{
			[self _presentMessage:newMessage withPresenter:messagePresenter activePresenter:YES];
		}
	});
}

- (void)dequeue:(OCMessage *)message
{
	[self _performOnMessage:message updates:^BOOL(NSMutableArray<OCMessage *> *messages, OCMessage *message) {
		if (message != nil)
		{
			message.removed = YES;
		}

		return (message != nil);
	}];
}

- (void)dequeueAllMessagesForBookmarkUUID:(OCBookmarkUUID)bookmarkUUID
{
	[self _performOnMessage:nil updates:^BOOL(NSMutableArray<OCMessage *> *messages, OCMessage *message) {
		BOOL messageRemoved = NO;

		for (OCMessage *message in messages)
		{
			if ((message.bookmarkUUID != nil) && ![message.bookmarkUUID isEqual:bookmarkUUID])
			{
				message.removed = YES;
				messageRemoved = YES;
			}
		}

		return (messageRemoved);
	}];
}

- (OCMessage *)messageWithUUID:(OCMessageUUID)messageUUID
{
	__block OCMessage *foundMessage = nil;

	// Check if the message is already known
	@synchronized(self)
	{
		for (OCMessage *message in _messages)
		{
			if ([message.uuid isEqual:messageUUID])
			{
				foundMessage = message;
				break;
			}
		}
	}

	// Load from storage and repeat search
	if (foundMessage == nil)
	{
		__block NSMutableArray<OCMessage *> *messages = nil;

		dispatch_sync(self->_workQueue, ^{
			messages = [self->_storage readObjectForKey:OCKeyValueStoreKeySyncIssueQueue];

			for (OCMessage *message in messages)
			{
				if ([message.uuid isEqual:messageUUID])
				{
					foundMessage = message;
					break;
				}
			}
		});

		self.messages = messages;
	}

	return (foundMessage);
}

#pragma mark - Queue Handling
- (void)setNeedsMessageHandling
{
	[_observerRateLimiter runRateLimitedBlock:^{
		dispatch_async(self->_workQueue, ^{
			[self _handleMessages];
		});
	}];
}

- (void)setMessages:(NSArray<OCMessage *> * _Nonnull)messages
{
	@synchronized(self)
	{
		_messages = messages;
	}
}

- (void)_handleMessages
{
	NSMutableSet<OCMessageUUID> *messageUUIDs = [NSMutableSet new];
	NSMutableSet<OCMessageUUID> *removedMessageUUIDs = nil;

	[_storage updateObjectForKey:OCKeyValueStoreKeySyncIssueQueue usingModifier:^id _Nullable(NSMutableArray<OCMessage *> *messages, BOOL *outDidModify) {
		NSMutableArray<OCMessage *> *newMessages = [messages mutableCopy];

		for (OCMessage *message in messages)
		{
			[messageUUIDs addObject:message.uuid];

			// Autoresolve
			if (!message.resolved && !message.removed)
			{
				NSArray<id<OCMessageAutoResolver>> *autoResolvers = nil;

				@synchronized(self->_autoResolvers)
				{
					autoResolvers = [self->_autoResolvers allObjects]; // Make sure response handlers aren't deallocated while looping through them
				}

				for (id<OCMessageAutoResolver> autoResolver in autoResolvers)
				{
					if ([autoResolver autoresolveMessage:message])
					{
						*outDidModify = YES;
					}
				}
			}

			// Check presentation options
			if (!message.presentedToUser && !message.resolved && !message.removed)
			{
				if ((message.lockingProcess == nil) ||
				    ((message.lockingProcess != nil) &&
				     ![OCProcessManager.sharedProcessManager isSessionWithCurrentProcessBundleIdentifier:message.lockingProcess] && // Not this app
				     ![OCProcessManager.sharedProcessManager isSessionValid:message.lockingProcess usingThoroughChecks:YES]) // Not valid
				   )
				{
					OCMessagePresenter *presenter;

					if ((presenter = [self presenterForMessage:message addToProcessedBy:YES]) != nil)
					{
						message.lockingProcess = OCProcessManager.sharedProcessManager.processSession;
						*outDidModify = YES;

						[self _presentMessage:message withPresenter:presenter activePresenter:YES];
					}
				}
			}

			// Handle result
			if (message.resolved && !message.removed)
			{
				NSArray<id<OCMessageResponseHandler>> *responseHandlers = nil;

				@synchronized(self->_responseHandlers)
				{
					responseHandlers = [self->_responseHandlers allObjects]; // Make sure response handlers aren't deallocated while looping through them
				}

				for (id<OCMessageResponseHandler> responseHandler in responseHandlers)
				{
					if ([responseHandler handleResponseToMessage:message])
					{
						message.removed = YES;
						*outDidModify = YES;
					}
				}

				// Auto-remove messages that indicate they want auto-removal
				if (!message.removed && message.autoRemove)
				{
					message.removed = YES;
					*outDidModify = YES;
				}
			}

			// Handle removal
			if (message.removed)
			{
				// Notify presenters of end of notification where it's required
				if (message.presentationRequiresEndNotification)
				{
					if ((message.presentationAppComponentIdentifier == nil) || // No binding to component
					   ((message.presentationAppComponentIdentifier != nil) && [message.presentationAppComponentIdentifier isEqual:OCAppIdentity.sharedAppIdentity.componentIdentifier])) // Binding to the current component
					{
						OCMessagePresenter *notifyPresenter = nil;

						@synchronized(self->_presenters)
						{
							for (OCMessagePresenter *presenter in self->_presenters)
							{
								if ([presenter.identifier isEqual:message.presentationPresenterIdentifier])
								{
									notifyPresenter = presenter;
									break;
								}
							}
						}

						if (notifyPresenter != nil)
						{
							// Notify presenter
							dispatch_async(dispatch_get_main_queue(), ^{
								[notifyPresenter endPresentationOfMessage:message];
							});

							// Remove presenter information
							message.presentationAppComponentIdentifier = nil;
							message.presentationPresenterIdentifier = nil;

							// Remove end notification requirement
							message.presentationRequiresEndNotification = NO;
							*outDidModify = YES;
						}
					}
				}

				// No end notification needed (or already performed) - message can be removed
				if (!message.presentationRequiresEndNotification)
				{
					[newMessages removeObject:message];
					*outDidModify = YES;
				}
			}
		}

		self.messages = newMessages;

		return (newMessages);
	}];

	// Determine removed message UUIDs
	@synchronized(self)
	{
		[_messageUUIDs minusSet:messageUUIDs];
		removedMessageUUIDs = _messageUUIDs;

		_messageUUIDs = messageUUIDs;
	}

	// Post notifications for removed messages
	if (removedMessageUUIDs.count > 0)
	{
		for (OCMessageUUID messageUUID in removedMessageUUIDs)
		{
			[NSNotificationCenter.defaultCenter postNotificationName:OCMessageRemovedNotification object:messageUUID];
		}
	}
}

#pragma mark - Issue resolution
- (void)resolveIssuesForError:(NSError *)error forBookmarkUUID:(OCBookmarkUUID)bookmarkUUID
{
	[self _performOnMessage:nil updates:^BOOL(NSMutableArray<OCMessage *> * _Nullable messages, OCMessage * _Nullable message) {
		BOOL updated = NO;

		for (OCMessage *message in messages)
		{
			if (!message.resolved && !message.removed && (message.syncIssue != nil) && [message.bookmarkUUID isEqual:bookmarkUUID])
			{
				for (OCSyncIssueChoice *choice in message.syncIssue.choices)
				{
					if ([choice.autoChoiceForError isEqual:error])
					{
						message.pickedChoice = choice;

						[self _notifyActivePresenterForEndOfPresentationOfMessage:message];

						updated = YES;
					}
				}
			}
		}

		return (updated);
	}];
}

- (void)resolveMessage:(OCMessage *)message withChoice:(OCMessageChoice *)choice
{
	[self _performOnMessage:message updates:^BOOL(NSMutableArray<OCMessage *> * _Nullable messages, OCMessage * _Nullable message) {
		BOOL updated = NO;

		if (!message.resolved && !message.removed && (message.choices != nil))
		{
			message.pickedChoice = choice;

			[self _notifyActivePresenterForEndOfPresentationOfMessage:message];

			updated = YES;
		}

		return (updated);
	}];
}

#pragma mark - Presentation
- (void)addPresenter:(OCMessagePresenter *)presenter
{
	if (presenter.identifier == nil)
	{
		OCLogError(@"BUG: presenter %@ does not provide any .identifier - not adding!", presenter);
		return;
	}

	@synchronized(_presenters)
	{
		[_presenters addObject:presenter];
		presenter.queue = self;
	}

	[self setNeedsMessageHandling];
}

- (void)removePresenter:(OCMessagePresenter *)presenter
{
	@synchronized(_presenters)
	{
		presenter.queue = nil;
		[_presenters removeObject:presenter];
	}
}

- (OCMessagePresenter *)presenterForMessage:(OCMessage *)message addToProcessedBy:(BOOL)addToProcessedBy
{
	OCMessagePresenter *presenter = nil;

	@synchronized(_presenters)
	{
		OCMessagePresentationPriority highestPresentationPriority = OCMessagePresentationPriorityWontPresent;

		for (OCMessagePresenter *presenterCandidate in _presenters)
		{
			OCMessagePresenterComponentSpecificIdentifier specificIdentifier = presenterCandidate.componentSpecificIdentifier;

			if (![message.processedBy containsObject:specificIdentifier])
			{
				OCMessagePresentationPriority presentationCandidatePriority = [presenterCandidate presentationPriorityFor:message];

				if (presentationCandidatePriority > highestPresentationPriority)
				{
					highestPresentationPriority = presentationCandidatePriority;
					presenter = presenterCandidate;
				}
			}

			if (addToProcessedBy)
			{
				message.processedBy = (message.processedBy==nil) ? [NSSet setWithObject:specificIdentifier] : [message.processedBy setByAddingObject:specificIdentifier];
			}
		}
	}

	return (presenter);
}

- (void)_presentMessage:(OCMessage *)message withPresenter:(OCMessagePresenter *)presenter activePresenter:(BOOL)activePresenter
{
	dispatch_async(dispatch_get_main_queue(), ^{
		if (activePresenter)
		{
			@synchronized(self->_activePresenterByMessageUUID)
			{
				[self->_activePresenterByMessageUUID setObject:presenter forKey:message.uuid];
			}
		}

		[presenter present:message completionHandler:^(OCMessagePresentationResult result, OCMessageChoice * _Nullable choice) {
			if (activePresenter)
			{
				@synchronized(self->_activePresenterByMessageUUID)
				{
					[self->_activePresenterByMessageUUID removeObjectForKey:message.uuid];
				}
			}

			[self _handlePresenter:presenter resultForMessage:message result:result choice:choice activePresenter:activePresenter];
		}];
	});
}

- (void)present:(OCMessage *)message withPresenter:(OCMessagePresenter *)presenter
{
	[self _presentMessage:message withPresenter:presenter activePresenter:NO];
}

- (void)_notifyActivePresenterForEndOfPresentationOfMessage:(OCMessage *)message
{
	OCMessagePresenter *presenter = nil;

	@synchronized(self->_activePresenterByMessageUUID)
	{
		presenter = [self->_activePresenterByMessageUUID objectForKey:message.uuid];
		[self->_activePresenterByMessageUUID removeObjectForKey:message.uuid];
	}

	if (presenter != nil)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			[presenter endPresentationOfMessage:message];
		});
	}
}

- (void)_handlePresenter:(OCMessagePresenter *)presenter resultForMessage:(OCMessage *)message result:(OCMessagePresentationResult)result choice:(OCMessageChoice *)choice activePresenter:(BOOL)activePresenter
{
	[self _performOnMessage:message updates:^BOOL(NSMutableArray<OCMessage *> *messages, OCMessage *message) {
		BOOL update = NO;
		BOOL didPresent = (result != 0);

		if (didPresent && !message.presentedToUser)
		{
			message.presentedToUser = YES;

			if ((result & OCMessagePresentationResultRequiresEndNotification) != 0)
			{
				message.presentationPresenterIdentifier = presenter.identifier;

				if ((result & OCMessagePresentationResultRequiresEndNotificationSameComponent) != 0)
				{
					message.presentationAppComponentIdentifier = OCAppIdentity.sharedAppIdentity.componentIdentifier;
				}

				message.presentationRequiresEndNotification = YES;
			}

			update = YES;
		}

		if (choice != nil)
		{
			message.pickedChoice = choice;

			[self _notifyActivePresenterForEndOfPresentationOfMessage:message];

			update = YES;
		}

		if (message.lockingProcess != nil)
		{
			message.lockingProcess = nil;
			update = YES;
		}

		return (update);
	}];
}

- (void)_performOnMessage:(nullable OCMessage *)message updates:(BOOL(^)(NSMutableArray<OCMessage *> * _Nullable messages, OCMessage * _Nullable message))updatePerformer
{
	dispatch_async(self->_workQueue, ^{
		[self __performOnMessage:message updates:updatePerformer];
	});
}

- (void)__performOnMessage:(nullable OCMessage *)message updates:(BOOL(^)(NSMutableArray<OCMessage *> * _Nullable messages, OCMessage * _Nullable message))updatePerformer
{
	__block BOOL didUpdate = NO;

	[_storage updateObjectForKey:OCKeyValueStoreKeySyncIssueQueue usingModifier:^id _Nullable(NSMutableArray<OCMessage *> *messages, BOOL *outDidModify) {
		OCMessage *storedMessage;

		for (OCMessage *inspectMessage in messages)
		{
			if ([inspectMessage.uuid isEqual:message.uuid])
			{
				storedMessage = inspectMessage;
				break;
			}
		}

		didUpdate = updatePerformer(messages, storedMessage);
		*outDidModify = didUpdate;

		self.messages = messages;

		return (messages);
	}];
}

#pragma mark - Auto resolver
- (void)addAutoResolver:(id<OCMessageAutoResolver>)autoResolver
{
	@synchronized(_autoResolvers)
	{
		[_autoResolvers addObject:autoResolver];
	}

	[self setNeedsMessageHandling];
}

- (void)removeAutoResolver:(id<OCMessageAutoResolver>)autoResolver
{
	@synchronized(_autoResolvers)
	{
		[_autoResolvers removeObject:autoResolver];
	}
}

#pragma mark - Response handling
- (void)addResponseHandler:(id<OCMessageResponseHandler>)responseHandler
{
	@synchronized(_responseHandlers)
	{
		[_responseHandlers addObject:responseHandler];
	}

	[self setNeedsMessageHandling];
}

- (void)removeResponseHandler:(id<OCMessageResponseHandler>)responseHandler
{
	@synchronized(_responseHandlers)
	{
		[_responseHandlers removeObject:responseHandler];
	}
}

@end

OCKeyValueStoreKey OCKeyValueStoreKeySyncIssueQueue = @"syncIssueQueue";
NSNotificationName OCMessageRemovedNotification = @"OCMessageRemovedNotification"; //!< Posted on all active processes with the message.uuid as notification.object - for messages that have been removed
