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
	__block OCMessagePresenter *messagePresenter = nil;

	if (newMessage == nil) { return; }

	dispatch_async(self->_workQueue, ^{
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

				if ((messagePresenter = [self presenterForMessage:newMessage addToProcessedBy:YES]) != nil)
				{
					newMessage.lockingProcess = OCProcessManager.sharedProcessManager.processSession;
				}
			}

			return (messages);
		}];

		if (messagePresenter != nil)
		{
			[self presentMessage:newMessage withPresenter:messagePresenter];
		}
	});
}

- (void)dequeue:(OCMessage *)message
{
	[self _performOnMessage:message updates:^BOOL(NSMutableArray<OCMessage *> *messages, OCMessage *message) {
		if (message != nil)
		{
			[messages removeObject:message];
		}
		return (message != nil);
	}];
}

- (void)dequeueAllMessagesForBookmarkUUID:(OCBookmarkUUID)bookmarkUUID
{
	[self _performOnMessage:nil updates:^BOOL(NSMutableArray<OCMessage *> *messages, OCMessage *message) {
		NSUInteger messagesCount = messages.count;

		[messages filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(OCMessage *message, NSDictionary<NSString *,id> * _Nullable bindings) {
			return ((message.bookmarkUUID == nil) || ((message.bookmarkUUID != nil) && ![message.bookmarkUUID isEqual:bookmarkUUID]));
		}]];

		return (messagesCount != messages.count);
	}];
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

- (void)_handleMessages
{
	[_storage updateObjectForKey:OCKeyValueStoreKeySyncIssueQueue usingModifier:^id _Nullable(NSMutableArray<OCMessage *> *messages, BOOL *outDidModify) {
		NSMutableArray<OCMessage *> *newMessages = [messages mutableCopy];

		for (OCMessage *message in messages)
		{
			// Check presentation options
			if (!message.presentedToUser)
			{
				if ((message.lockingProcess == nil) ||
				    ((message.lockingProcess != nil) &&
				     ![message.lockingProcess isEqual:OCProcessManager.sharedProcessManager.processSession] &&
				     ![OCProcessManager.sharedProcessManager isSessionValid:message.lockingProcess usingThoroughChecks:YES])
				   )
				{
					OCMessagePresenter *presenter;

					if ((presenter = [self presenterForMessage:message addToProcessedBy:YES]) != nil)
					{
						message.lockingProcess = OCProcessManager.sharedProcessManager.processSession;
						*outDidModify = YES;

						[self presentMessage:message withPresenter:presenter];
					}
				}
			}

			// Handle result
			if (message.handled)
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
						[newMessages removeObject:message];
						*outDidModify = YES;
					}
				}
			}
		}

		return (newMessages);
	}];
}

#pragma mark - Issue resolution
- (void)resolveIssuesForError:(NSError *)error forBookmarkUUID:(OCBookmarkUUID)bookmarkUUID
{
	[self _performOnMessage:nil updates:^BOOL(NSMutableArray<OCMessage *> * _Nullable messages, OCMessage * _Nullable message) {
		BOOL updated = NO;

		for (OCMessage *message in messages)
		{
			if (!message.handled && (message.syncIssue != nil) && [message.bookmarkUUID isEqual:bookmarkUUID])
			{
				for (OCSyncIssueChoice *choice in message.syncIssue.choices)
				{
					if ([choice.autoChoiceForError isEqual:error])
					{
						message.syncIssueChoice = choice;
						updated = YES;
					}
				}
			}
		}

		return (updated);
	}];
}

- (void)resolveMessage:(OCMessage *)message withChoice:(OCSyncIssueChoice *)choice
{
	[self _performOnMessage:message updates:^BOOL(NSMutableArray<OCMessage *> * _Nullable messages, OCMessage * _Nullable message) {
		BOOL updated = NO;

		if (!message.handled && (message.syncIssue != nil))
		{
			message.syncIssueChoice = choice;
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

- (void)presentMessage:(OCMessage *)message withPresenter:(OCMessagePresenter *)presenter
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[presenter present:message completionHandler:^(BOOL didPresent, OCSyncIssueChoice * _Nullable choice) {
			[self _handlePresentationResultForMessage:message didPresent:didPresent choice:choice];
		}];
	});
}

- (void)_handlePresentationResultForMessage:(OCMessage *)message didPresent:(BOOL)didPresent choice:(OCSyncIssueChoice *)choice
{
	[self _performOnMessage:message updates:^BOOL(NSMutableArray<OCMessage *> *messages, OCMessage *message) {
		BOOL update = NO;

		if (didPresent && !message.presentedToUser)
		{
			message.presentedToUser = YES;
			update = YES;
		}

		if (choice != nil)
		{
			message.syncIssueChoice = choice;
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

		return (messages);
	}];
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
