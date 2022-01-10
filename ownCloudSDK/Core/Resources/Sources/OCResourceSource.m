//
//  OCResourceSource.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.02.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCResourceSource.h"
#import "NSError+OCError.h"
#import "OCCore.h"
#import "OCCore+Internal.h"
#import "OCMacros.h"

@implementation OCResourceSource

- (instancetype)initWithCore:(OCCore *)core
{
	if ((self = [super init]) != nil)
	{
		_core = core;
		_eventHandlerIdentifier = [NSString stringWithFormat:@"%@-%@-%@", NSStringFromClass(self.class), self.identifier, core.bookmark.uuid.UUIDString];
	}

	return (self);
}

- (OCResourceSourcePriority)priorityForType:(OCResourceType)type
{
	return (OCResourceSourcePriorityNone);
}

- (OCResourceQuality)qualityForRequest:(OCResourceRequest *)request
{
	return (OCResourceQualityNone);
}

- (void)provideResourceForRequest:(OCResourceRequest *)request shouldContinueHandler:(nullable OCResourceSourceShouldContinueHandler)shouldContinueHandler resultHandler:(OCResourceSourceResultHandler)resultHandler
{
	if (resultHandler != nil)
	{
		resultHandler(OCError(OCErrorFeatureNotImplemented), nil);
	}
}

#pragma mark - Event handling integration
- (BOOL)shouldRegisterEventHandler
{
	return (NO);
}

- (void)registerEventHandler
{
	[OCEvent registerEventHandler:self forIdentifier:self.eventHandlerIdentifier];
}

- (void)unregisterEventHandler
{
	[OCEvent registerEventHandler:nil forIdentifier:self.eventHandlerIdentifier];
}

- (void)handleEvent:(OCEvent *)event sender:(id)sender
{
	NSString *eventActivityString = [[NSString alloc] initWithFormat:@"Handling event %@ (resource source)", event];

	[self.core beginActivity:eventActivityString];

	NSString *selectorName;

	if ((selectorName = OCTypedCast(event.userInfo[OCEventUserInfoKeySelector], NSString)) != nil)
	{
		// Selector specified -> route event directly to selector
		SEL eventHandlingSelector;

		if ((eventHandlingSelector = NSSelectorFromString(selectorName)) != NULL)
		{
			// Below is identical to [self performSelector:eventHandlingSelector withObject:event withObject:sender], but in an ARC-friendly manner.
			void (*impFunction)(id, SEL, OCEvent *, id) = (void *)[((NSObject *)self) methodForSelector:eventHandlingSelector];

			[self.core queueBlock:^{
				if (impFunction != NULL)
				{
					impFunction(self, eventHandlingSelector, event, sender);
				}

				[self.core endActivity:eventActivityString];
			}];
		}
	}
	else
	{
		OCLogError(@"Unroutable resource source event: %@", event);
	}
}

@end
