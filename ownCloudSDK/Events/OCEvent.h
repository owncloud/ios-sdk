//
//  OCEvent.h
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

#import <Foundation/Foundation.h>
#import "OCTypes.h"

typedef NSString* OCEventHandlerIdentifier;
typedef NSString* OCEventUserInfoKey NS_TYPED_ENUM;

typedef NS_ENUM(NSUInteger, OCEventType)
{
	OCEventTypeNone,

	// Creation
	OCEventTypeCreateFolder,
	OCEventTypeCreateEmptyFile,
	OCEventTypeCreateShare,

	// Modification
	OCEventTypeMove,
	OCEventTypeCopy,
	OCEventTypeDelete,

	// File Transfers
	OCEventTypeUpload,
	OCEventTypeDownload,

	// Metadata
	OCEventTypeRetrieveThumbnail,
	OCEventTypeRetrieveItemList,
	OCEventTypeUpdate,

	// Issues
	OCEventTypeIssueResponse
};

@class OCEvent;
@class OCEventTarget;
@class OCFile;

NS_ASSUME_NONNULL_BEGIN

@protocol OCEventHandler <NSObject>

- (void)handleEvent:(OCEvent *)event sender:(id)sender;

@end

typedef void(^OCEventHandlerBlock)(OCEvent *event, id sender);

@interface OCEvent : NSObject <NSSecureCoding>
{
	OCEventType _eventType;

	NSDictionary<OCEventUserInfoKey,id<NSObject,NSSecureCoding>> *_userInfo;
	NSDictionary<OCEventUserInfoKey,id> *_ephermalUserInfo;

	OCPath _path;
	NSUInteger _depth;

	NSString *_mimeType;
	NSData *_data;
	NSError *_error;
	id<NSObject,NSSecureCoding>  _result;

	OCDatabaseID _databaseID;
}

@property(assign) OCEventType eventType;	//!< The type of event this object describes.

@property(nullable,readonly) NSDictionary<OCEventUserInfoKey,id<NSObject,NSSecureCoding>> *userInfo;	//!< The userInfo value of the OCEventTarget used to create this event.
@property(nullable,readonly) NSDictionary<OCEventUserInfoKey,id> *ephermalUserInfo; //!< The ephermalUserInfo value of the OCEventTarget used to create this event.

@property(nullable,strong) OCPath path;		//!< Used by OCEventTypeRetrieveItemList.
@property(assign) NSUInteger depth;	//!< Used by OCEventTypeRetrieveItemList.

@property(nullable,strong) NSString *mimeType;
@property(nullable,strong) NSData *data;
@property(nullable,strong) OCFile *file;

@property(nullable,strong) NSError *error;
@property(nullable,strong) id<NSObject,NSSecureCoding> result;

@property(nullable,strong) OCDatabaseID databaseID; //!< Used by OCDatabase to track an event. (ephermal)

#pragma mark - Event handler registration / resolution
+ (void)registerEventHandler:(nullable id <OCEventHandler>)eventHandler forIdentifier:(OCEventHandlerIdentifier)eventHandlerIdentifier; //!< Registers an event handler for a particular name. Remove with a nil value for eventHandler.
+ (void)unregisterEventHandlerForIdentifier:(OCEventHandlerIdentifier)eventHandlerIdentifier; //!< Unregister an event handler.
+ (nullable id <OCEventHandler>)eventHandlerWithIdentifier:(OCEventHandlerIdentifier)eventHandlerIdentifier; //!< Retrieves the event handler stored for a particular identifier.

#pragma mark - Creating events
+ (instancetype)eventForEventTarget:(OCEventTarget *)eventTarget type:(OCEventType)eventType attributes:(nullable NSDictionary *)attributes; //!< Creates an event using the userInfo and ephermalUserInfo from the supplied eventTarget as well as the passed in type and attributes.

+ (instancetype)eventWithType:(OCEventType)eventType userInfo:(nullable NSDictionary<OCEventUserInfoKey,id<NSSecureCoding>> *)userInfo ephermalUserInfo:(nullable NSDictionary<OCEventUserInfoKey,id> *)ephermalUserInfo result:(nullable id)result; //!< Creates an event using of the specified type using the provided userInfo and ephermalUserInfo

#pragma mark - Serialization tools
+ (nullable instancetype)eventFromSerializedData:(NSData *)serializedData;
- (nullable NSData *)serializedData;

@end

extern OCEventUserInfoKey OCEventUserInfoKeyItem;
extern OCEventUserInfoKey OCEventUserInfoKeyItemVersionIdentifier;

NS_ASSUME_NONNULL_END

