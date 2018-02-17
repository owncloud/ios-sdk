//
//  OCEvent.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCEvent.h"

@implementation OCEvent

@synthesize eventID = _eventID;
@synthesize eventType = _eventType;

@synthesize attributes = _attributes;

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

+ (id <OCEventHandler>)eventHandlerWithIdentifier:(OCEventHandlerIdentifier)eventHandlerIdentifier
{
	if (eventHandlerIdentifier != nil)
	{
		return ([[self _eventHandlerDictionary] objectForKey:eventHandlerIdentifier]);
	}
	
	return (nil);
}

@end
