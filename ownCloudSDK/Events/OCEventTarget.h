//
//  OCEventTarget.h
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
#import "OCEvent.h"

@interface OCEventTarget : NSObject <NSSecureCoding>
{
	OCEventHandlerIdentifier _eventHandlerIdentifier;

	NSDictionary *_userInfo;
	NSDictionary *_ephermalUserInfo;
}

@property(readonly) OCEventHandlerIdentifier eventHandlerIdentifier; //!< Identifies the event handler to target by identifier. Can be retrieved via +[OCEvent eventHandlerWithIdentifier:].
@property(readonly) NSDictionary *userInfo; //!< "Permanent" storage for use by the sender. All contents must be serializable via NSSecureCoding.
@property(readonly) NSDictionary *ephermalUserInfo; //!< "Ephermal" storage for use by the sender. Can contain any contents (including blocks), but sender shouldn't rely on getting it back. It will be lost f.ex. for requests on background sessions if the app is terminated before the request finishes.

+ (instancetype)eventTargetWithEventHandlerIdentifier:(OCEventHandlerIdentifier)eventHandlerIdentifier userInfo:(NSDictionary *)userInfo ephermalUserInfo:(NSDictionary *)ephermalUserInfo; //!< Creates a new event target using an event handler identifier, userInfo and ephermalUserInfo. See the property descriptions for more information on these.

- (void)handleEvent:(OCEvent *)event sender:(id)sender; //!< Resolves the eventHandlerIdentifier and sends the event to the resolved event handler. Subclasses can use different mechanisms (like f.ex. deliver the event to a block it keeps).

- (void)handleError:(NSError *)error type:(OCEventType)type sender:(id)sender; //!< Convenience method that builds an OCEvent with the provided error and sends it to the event target.

@end
