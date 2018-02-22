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
	OCEventID _eventID;
	OCEventHandlerIdentifier _eventHandlerIdentifier;
}

@property(readonly) OCEventID eventID;
@property(readonly) OCEventHandlerIdentifier eventHandlerIdentifier;

+ (instancetype)eventTargetWithEventID:(OCEventID)eventID eventHandlerIdentifier:(OCEventHandlerIdentifier)eventHandlerIdentifier;

- (void)handleEvent:(OCEvent *)event sender:(id)sender; //!< Resolves the eventHandlerIdentifier and sends the event to the resolved event handler. Subclasses can use different mechanisms (like f.ex. deliver the event to a block it keeps).

@end
