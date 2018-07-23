//
//  OCEvent.m
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

#import "OCEvent.h"
#import "OCEventTarget.h"

@implementation OCEvent

@synthesize eventType = _eventType;

@synthesize userInfo = _userInfo;
@synthesize ephermalUserInfo = _ephermalUserInfo;

@synthesize attributes = _attributes;

@synthesize path = _path;
@synthesize depth = _depth;

@synthesize mimeType = _mimeType;
@synthesize data = _data;
@synthesize error = _error;
@synthesize result = _result;

+ (NSMutableDictionary <OCEventHandlerIdentifier, id <OCEventHandler>> *)_eventHandlerDictionary
{
	static dispatch_once_t onceToken;
	static NSMutableDictionary <OCEventHandlerIdentifier, id <OCEventHandler>> *eventHandlerDictionary;
	dispatch_once(&onceToken, ^{
		eventHandlerDictionary = [NSMutableDictionary new];
	});
	
	return (eventHandlerDictionary);
}

+ (void)registerEventHandler:(id <OCEventHandler>)eventHandler forIdentifier:(OCEventHandlerIdentifier)eventHandlerIdentifier
{
	if (eventHandlerIdentifier != nil)
	{
		if (eventHandler != nil)
		{
			[[self _eventHandlerDictionary] setObject:eventHandler forKey:eventHandlerIdentifier];
		}
		else
		{
			[[self _eventHandlerDictionary] removeObjectForKey:eventHandlerIdentifier];
		}
	}
}

+ (void)unregisterEventHandlerForIdentifier:(OCEventHandlerIdentifier)eventHandlerIdentifier
{
	[self registerEventHandler:nil forIdentifier:eventHandlerIdentifier];
}

+ (id <OCEventHandler>)eventHandlerWithIdentifier:(OCEventHandlerIdentifier)eventHandlerIdentifier
{
	if (eventHandlerIdentifier != nil)
	{
		return ([[self _eventHandlerDictionary] objectForKey:eventHandlerIdentifier]);
	}
	
	return (nil);
}

+ (instancetype)eventForEventTarget:(OCEventTarget *)eventTarget type:(OCEventType)eventType attributes:(NSDictionary *)attributes
{
	return ([[self alloc] initForEventTarget:eventTarget type:eventType attributes:attributes]);
}

- (instancetype)initForEventTarget:(OCEventTarget *)eventTarget type:(OCEventType)eventType attributes:(NSDictionary *)attributes
{
	if ((self = [super init]) != nil)
	{
		_eventType = eventType;

		_userInfo = eventTarget.userInfo;
		_ephermalUserInfo = eventTarget.ephermalUserInfo;

		_attributes = attributes;
	}

	return(self);
}


@end
