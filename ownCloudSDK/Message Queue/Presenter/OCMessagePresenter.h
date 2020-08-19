//
//  OCMessagePresenter.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.03.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, OCMessagePresentationPriority)
{
	OCMessagePresentationPriorityWontPresent,	//!< The presenter won't present this issue.

	OCMessagePresentationPriorityLow = 100,	//!< The presenter can present the issue, but probably only as a fallback
	OCMessagePresentationPriorityDefault = 200,	//!< The presenter can present the issue
	OCMessagePresentationPriorityHigh = 300	//!< The presenter wants priority in the presentation of the issue
};

typedef NS_OPTIONS(NSUInteger, OCMessagePresentationResult)
{
	OCMessagePresentationResultDidNotPresent = 0, //!< Use [] in Swift (which seems to drop .didNotPresent because of its 0 value)

	OCMessagePresentationResultDidPresent = (1<<0),
	OCMessagePresentationResultRequiresEndNotification = (1<<1),
	OCMessagePresentationResultRequiresEndNotificationSameComponent = (1<<2)
};

@class OCMessageQueue;
@class OCMessage;
@class OCMessageChoice;

typedef NSString* OCMessagePresenterIdentifier NS_TYPED_ENUM;
typedef NSString* OCMessagePresenterComponentSpecificIdentifier;

@interface OCMessagePresenter : NSObject

@property(weak,nullable) OCMessageQueue *queue; //!< Queue this presenter was added to
@property(strong) OCMessagePresenterIdentifier identifier; //!< Identifier of this presenter

@property(readonly,nonatomic) OCMessagePresenterComponentSpecificIdentifier componentSpecificIdentifier; //!< App-Component-specific identifier, built from OCAppIdentity.componentIdentifier and .identifier

- (OCMessagePresentationPriority)presentationPriorityFor:(OCMessage *)message; //!< Return the priority with which the presenter wants to present the record's issue. Return OCSyncIssuePresentationPriorityWontPresent to signal the record's issue shouldn't be presented through this presenter
- (void)present:(OCMessage *)message completionHandler:(void(^)(OCMessagePresentationResult result, OCMessageChoice * _Nullable choice))completionHandler; //!< Present the record's issue

- (void)endPresentationOfMessage:(OCMessage *)message; //!< End the presentation of a message

@end

NS_ASSUME_NONNULL_END
