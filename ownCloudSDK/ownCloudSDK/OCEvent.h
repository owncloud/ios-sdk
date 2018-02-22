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
typedef NSInteger OCEventID;
#define OCEventIDUnknown ((OCEventID)-1)

typedef NS_ENUM(NSUInteger, OCEventType)
{
	OCEventTypeCreateFolder,
	OCEventTypeCreateEmptyFile,
	OCEventTypeMove,
	OCEventTypeCopy,
	OCEventTypeDelete,
	OCEventTypeUpload,
	OCEventTypeDownload,
	OCEventTypeRetrieveThumbnail,
	OCEventTypeCreateShare
};

@class OCEvent;

@protocol OCEventHandler <NSObject>

- (void)handleEvent:(OCEvent *)event sender:(id)sender;

@end

@interface OCEvent : NSObject
{
	OCEventID _eventID;
	OCEventType _eventType;

	NSDictionary *_attributes;
}

@property(assign) OCEventID eventID; 	//!< For events created in reaction to a command, the eventID passed to the command. OCEventIDUnknown otherwise.
@property(assign) OCEventType eventType;	//!< The type of event this object describes.

@property(strong) NSDictionary *attributes;	//!< Attributes of the event, describing what happened. (Catch-all in first draft, will be supplemented with additional object properties before implementation)

+ (void)registerEventHandler:(id <OCEventHandler>)eventHandler forIdentifier:(OCEventHandlerIdentifier)eventHandlerIdentifier; //!< Registers an event handler for a particular name. Remove with a nil value for eventHandler.
+ (id <OCEventHandler>)eventHandlerWithIdentifier:(OCEventHandlerIdentifier)eventHandlerIdentifier; //!< Retrieves the event handler stored for a particular identifier.

@end
