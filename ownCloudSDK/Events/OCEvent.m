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
#import "OCLogger.h"

@implementation OCEvent

@synthesize eventType = _eventType;

@synthesize userInfo = _userInfo;
@synthesize ephermalUserInfo = _ephermalUserInfo;

@synthesize path = _path;
@synthesize depth = _depth;

@synthesize mimeType = _mimeType;
@synthesize data = _data;
@synthesize error = _error;
@synthesize result = _result;

@synthesize databaseID = _databaseID;

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

+ (instancetype)eventWithType:(OCEventType)eventType userInfo:(NSDictionary<OCEventUserInfoKey,id> *)userInfo ephermalUserInfo:(NSDictionary<OCEventUserInfoKey,id> *)ephermalUserInfo result:(id)result
{
	OCEvent *event;

	event = [OCEvent new];
	event->_eventType = eventType;
	event->_userInfo = userInfo;
	event->_ephermalUserInfo = ephermalUserInfo;
	event.result = result;

	return (event);
}

- (instancetype)initForEventTarget:(OCEventTarget *)eventTarget type:(OCEventType)eventType attributes:(NSDictionary *)attributes
{
	if ((self = [super init]) != nil)
	{
		_eventType = eventType;

		_userInfo = eventTarget.userInfo;
		_ephermalUserInfo = eventTarget.ephermalUserInfo;
	}

	return(self);
}


#pragma mark - Serialization tools
+ (instancetype)eventFromSerializedData:(NSData *)serializedData
{
	if (serializedData != nil)
	{
		return ([NSKeyedUnarchiver unarchiveObjectWithData:serializedData]);
	}

	return (nil);
}

- (NSData *)serializedData
{
	NSData *serializedData = nil;

	@try {
		serializedData = ([NSKeyedArchiver archivedDataWithRootObject:self]);
	}
	@catch (NSException *exception) {
		OCLogError(@"Error serializing event=%@ with exception=%@", self, exception);
	}

	return (serializedData);
}

#pragma mark - Secure coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		_eventType = [decoder decodeIntegerForKey:@"eventType"];
		_userInfo = [decoder decodeObjectOfClass:[NSDictionary class] forKey:@"userInfo"];

		_path = [decoder decodeObjectOfClass:[NSString class] forKey:@"path"];
		_depth = [decoder decodeIntegerForKey:@"depth"];

		_mimeType = [decoder decodeObjectOfClass:[NSString class] forKey:@"mimeType"];
		_data = [decoder decodeObjectOfClass:[NSString class] forKey:@"data"];
		_error = [decoder decodeObjectOfClass:[NSError class] forKey:@"error"];
		_result = [decoder decodeObjectOfClass:[NSObject class] forKey:@"result"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInteger:_eventType forKey:@"eventType"];

	[coder encodeObject:_userInfo forKey:@"userInfo"];

	[coder encodeObject:_path forKey:@"path"];
	[coder encodeInteger:_depth forKey:@"depth"];

	[coder encodeObject:_mimeType forKey:@"mimeType"];
	[coder encodeObject:_data forKey:@"data"];
	[coder encodeObject:_error forKey:@"error"];
	[coder encodeObject:_result forKey:@"result"];
}

@end

OCEventUserInfoKey OCEventUserInfoKeyItem = @"item";
OCEventUserInfoKey OCEventUserInfoKeyItemVersionIdentifier = @"itemVersionIdentifier";
