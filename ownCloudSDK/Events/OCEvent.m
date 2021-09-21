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

#import "OCBookmark.h"
#import "OCCertificate.h"
#import "OCChecksum.h"
#import "OCClaim.h"
#import "OCEventRecord.h"
#import "OCFile.h"
#import "OCGroup.h"
#import "OCHTTPPipelineTaskMetrics.h"
#import "OCHTTPRequest.h"
#import "OCHTTPResponse.h"
#import "OCHTTPStatus.h"
#import "OCHTTPPolicy.h"
#import "OCImage.h"
#import "OCItem.h"
#import "OCItemPolicy.h"
#import "OCItemThumbnail.h"
#import "OCItemVersionIdentifier.h"
#import "OCProcessSession.h"
#import "OCRecipient.h"
#import "OCQueryCondition.h"
#import "OCShare.h"
#import "OCSyncIssue.h"
#import "OCSyncIssueChoice.h"
#import "OCUser.h"
#import "OCWaitCondition.h"
#import "OCTUSJob.h"
#import "OCTUSHeader.h"
#import "OCMessageChoice.h"
#import "OCDAVRawResponse.h"
#import "OCMessage.h"

@implementation OCEvent

@synthesize eventType = _eventType;
@synthesize uuid = _uuid;

@synthesize userInfo = _userInfo;
@synthesize ephermalUserInfo = _ephermalUserInfo;

@synthesize path = _path;
@synthesize depth = _depth;

@synthesize mimeType = _mimeType;
@synthesize file = _file;

@synthesize error = _error;
@synthesize result = _result;

@synthesize databaseID = _databaseID;

+ (NSSet<Class> *)safeClasses
{
	static dispatch_once_t onceToken;
	static NSSet<Class> *safeClasses;

	dispatch_once(&onceToken, ^{
		safeClasses = [[NSSet alloc] initWithObjects:
				// OC classes
				OCBookmark.class,
				OCCertificate.class,
				OCChecksum.class,
				OCClaim.class,
				OCEvent.class,
				OCEventTarget.class,
				OCEventRecord.class,
				OCFile.class,
				OCGroup.class,
				OCHTTPPipelineTaskMetrics.class,
				OCHTTPRequest.class,
				OCHTTPResponse.class,
				OCHTTPStatus.class,
				OCHTTPPolicy.class,
				OCDAVRawResponse.class,
				OCImage.class,
				OCItem.class,
				OCItemPolicy.class,
				OCItemThumbnail.class,
				OCItemVersionIdentifier.class,
				OCProcessSession.class,
				OCProgress.class,
				OCRecipient.class,
				OCQueryCondition.class,
				OCShare.class,
				OCSyncIssue.class,
				OCSyncIssueChoice.class,
				OCUser.class,
				OCWaitCondition.class,
				OCTUSHeader.class,
				OCTUSJob.class,
				OCTUSJobSegment.class,
				OCMessage.class,
				OCMessageChoice.class,

				// Foundation classes
				NSArray.class,
				NSAttributedString.class,
				NSData.class,
				NSDate.class,
				NSDateInterval.class,
				NSDictionary.class,
				NSIndexPath.class,
				NSIndexSet.class,
				NSOrderedSet.class,
				NSSet.class,
				NSString.class,
				NSNumber.class,
				NSNull.class,
				NSURL.class,
				NSUUID.class,
				NSValue.class,

				NSURLRequest.class,
				NSURLResponse.class,
				NSHTTPCookie.class,

				NSError.class,
		nil];
	});

	return (safeClasses);
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_uuid = NSUUID.UUID.UUIDString;
	}

	return (self);
}

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

+ (instancetype)eventForEventTarget:(OCEventTarget *)eventTarget type:(OCEventType)eventType uuid:(nullable OCEventUUID)uuid  attributes:(NSDictionary *)attributes
{
	return ([[self alloc] initForEventTarget:eventTarget type:eventType uuid:uuid attributes:attributes]);
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

- (instancetype)initForEventTarget:(OCEventTarget *)eventTarget type:(OCEventType)eventType uuid:(OCEventUUID)uuid attributes:(NSDictionary *)attributes
{
	if ((self = [self init]) != nil)
	{
		_eventType = eventType;

		if (uuid != nil)
		{
			_uuid = uuid;
		}

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

- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p, eventType: %lu, path: %@, uuid: %@, userInfo: %@, result: %@, file: %@%@%@>", NSStringFromClass(self.class), self, (unsigned long)_eventType, _path, _uuid, _userInfo, _result, _file, ((_ephermalUserInfo[@"_processSession"]!=nil)?[NSString stringWithFormat:@", processSession=%@",_ephermalUserInfo[@"_processSession"]]:@""), ((_ephermalUserInfo[@"_doProcess"]!=nil)?[NSString stringWithFormat:@", doProcess=%@",_ephermalUserInfo[@"_doProcess"]]:@"")]);
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
		_uuid = [decoder decodeObjectOfClass:NSString.class forKey:@"uuid"];

		_eventType = [decoder decodeIntegerForKey:@"eventType"];
		_userInfo = [decoder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"userInfo"];

		_path = [decoder decodeObjectOfClass:NSString.class forKey:@"path"];
		_depth = [decoder decodeIntegerForKey:@"depth"];

		_mimeType = [decoder decodeObjectOfClass:NSString.class forKey:@"mimeType"];
		_file = [decoder decodeObjectOfClass:OCFile.class forKey:@"file"];

		_error = [decoder decodeObjectOfClass:NSError.class forKey:@"error"];
		_result = [decoder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"result"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_uuid forKey:@"uuid"];

	[coder encodeInteger:_eventType forKey:@"eventType"];

	[coder encodeObject:_userInfo forKey:@"userInfo"];

	[coder encodeObject:_path forKey:@"path"];
	[coder encodeInteger:_depth forKey:@"depth"];

	[coder encodeObject:_mimeType forKey:@"mimeType"];
	[coder encodeObject:_file forKey:@"file"];

	[coder encodeObject:_error forKey:@"error"];
	[coder encodeObject:_result forKey:@"result"];
}

@end

OCEventUserInfoKey OCEventUserInfoKeyItem = @"item";
OCEventUserInfoKey OCEventUserInfoKeyItemVersionIdentifier = @"itemVersionIdentifier";
OCEventUserInfoKey OCEventUserInfoKeySelector = @"selector";
