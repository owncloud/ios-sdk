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

typedef NSString* OCEventHandlerIdentifier;

typedef NS_ENUM(NSUInteger, OCEventType)
{
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
	OCEventTypeRetrieveItemList
};

@class OCEvent;
@class OCEventTarget;
@class OCFile;

@protocol OCEventHandler <NSObject>

- (void)handleEvent:(OCEvent *)event sender:(id)sender;

@end

typedef void(^OCEventHandlerBlock)(OCEvent *event, id sender);

@interface OCEvent : NSObject
{
	OCEventType _eventType;

	NSDictionary *_userInfo;
	NSDictionary *_ephermalUserInfo;

	NSDictionary *_attributes;

	NSString *_mimeType;
	NSData *_data;
	NSError *_error;
	id _result;
}

@property(assign) OCEventType eventType;	//!< The type of event this object describes.

@property(readonly) NSDictionary *userInfo;	//!< The userInfo value of the OCEventTarget used to create this event.
@property(readonly) NSDictionary *ephermalUserInfo; //!< The ephermalUserInfo value of the OCEventTarget used to create this event.

@property(strong) NSDictionary *attributes;	//!< Attributes of the event, describing what happened. (Catch-all in first draft, will be supplemented with additional object properties before implementation)

@property(strong) NSString *mimeType;
@property(strong) NSData *data;
@property(strong) OCFile *file;
@property(strong) NSError *error;
@property(strong) id result;

#pragma mark - Event handler registration / resolution
+ (void)registerEventHandler:(id <OCEventHandler>)eventHandler forIdentifier:(OCEventHandlerIdentifier)eventHandlerIdentifier; //!< Registers an event handler for a particular name. Remove with a nil value for eventHandler.
+ (void)unregisterEventHandlerForIdentifier:(OCEventHandlerIdentifier)eventHandlerIdentifier; //!< Unregister an event handler.
+ (id <OCEventHandler>)eventHandlerWithIdentifier:(OCEventHandlerIdentifier)eventHandlerIdentifier; //!< Retrieves the event handler stored for a particular identifier.

#pragma mark - Creating events
+ (instancetype)eventForEventTarget:(OCEventTarget *)eventTarget type:(OCEventType)eventType attributes:(NSDictionary *)attributes; //!< Creates an event using the userInfo and ephermalUserInfo from the supplied eventTarget as well as the passed in type and attributes.

@end
