//
//  OCEventTarget.m
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

#import "OCEventTarget.h"
#import "OCLogger.h"

@interface OCEventTarget ()
{
	OCEventHandlerBlock _eventHandlerBlock;
}

@end

@implementation OCEventTarget

@synthesize eventHandlerIdentifier = _eventHandlerIdentifier;

@synthesize userInfo = _userInfo;
@synthesize ephermalUserInfo = _ephermalUserInfo;

#pragma mark - Init
+ (instancetype)eventTargetWithEventHandlerIdentifier:(OCEventHandlerIdentifier)eventHandlerIdentifier userInfo:(NSDictionary *)userInfo ephermalUserInfo:(NSDictionary *)ephermalUserInfo
{
	return ([[self alloc] initWithEventHandlerIdentifier:eventHandlerIdentifier userInfo:userInfo ephermalUserInfo:ephermalUserInfo]);
}

- (instancetype)initWithEventHandlerIdentifier:(OCEventHandlerIdentifier)eventHandlerIdentifier userInfo:(NSDictionary *)userInfo ephermalUserInfo:(NSDictionary *)ephermalUserInfo
{
	if ((self = [super init]) != nil)
	{
		_eventHandlerIdentifier = eventHandlerIdentifier;

		_userInfo = userInfo;
		_ephermalUserInfo = ephermalUserInfo;
	}
	
	return (self);
}

+ (instancetype)eventTargetWithEphermalEventHandlerBlock:(OCEventHandlerBlock)eventHandlerBlock userInfo:(NSDictionary *)userInfo ephermalUserInfo:(NSDictionary *)ephermalUserInfo
{
	return ([[self alloc] initWithEphermalEventHandlerBlock:eventHandlerBlock userInfo:userInfo ephermalUserInfo:ephermalUserInfo]);
}

- (instancetype)initWithEphermalEventHandlerBlock:(OCEventHandlerBlock)eventHandlerBlock userInfo:(NSDictionary *)userInfo ephermalUserInfo:(NSDictionary *)ephermalUserInfo
{
	if ((self = [super init]) != nil)
	{
		_eventHandlerBlock = [eventHandlerBlock copy];
		_userInfo = userInfo;
		_ephermalUserInfo = ephermalUserInfo;
	}

	return (self);
}

#pragma mark - Event handler
- (void)handleEvent:(OCEvent *)event sender:(id)sender
{
	if (_eventHandlerBlock == nil)
	{
		id <OCEventHandler> eventHandler = [OCEvent eventHandlerWithIdentifier:_eventHandlerIdentifier];

		if (eventHandler != nil)
		{
			[eventHandler handleEvent:event sender:sender];
		}
		else
		{
			OCLogError(@"DROPPING EVENT: event handler with identifier %@ not found - dropping event %@ from sender %@", _eventHandlerIdentifier, event, sender);
		}
	}
	else
	{
		_eventHandlerBlock(event, sender);
	}
}

#pragma mark - Convenience
- (void)handleError:(NSError *)error type:(OCEventType)type uuid:(nullable OCEventUUID)uuid sender:(id)sender
{
	OCEvent *event = [OCEvent eventForEventTarget:self type:type uuid:uuid attributes:nil];

	event.error = error;

	[self handleEvent:event sender:sender];
}

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		_eventHandlerIdentifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"eventHandlerIdentifier"];
		_userInfo = [decoder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"userInfo"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_eventHandlerIdentifier forKey:@"eventHandlerIdentifier"];
	[coder encodeObject:_userInfo forKey:@"userInfo"];
}

@end
