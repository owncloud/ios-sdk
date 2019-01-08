//
//  OCWaitConditionPendingUserInteraction.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.12.18.
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

#import "OCWaitCondition.h"
#import "OCProcessSession.h"

NS_ASSUME_NONNULL_BEGIN

/*
	OCWaitConditionPendingUserInteraction:
	- resolves without error if its userInteractionIdentifier is not contained in the OCWaitConditionOptionPendingUserInteractionIdentifiers list.
	- resolves with an OCErrorInvalidProcess error if processSession is no longer valid.
	- does not resolve in all other cases.
*/

@interface OCWaitConditionPendingUserInteraction : OCWaitCondition

@property(strong) id<NSObject,NSSecureCoding> userInteractionIdentifier;
@property(strong) OCProcessSession *processSession;

+ (instancetype)waitForUserInteractionWithIdentifier:(id<NSObject,NSSecureCoding>)userInteractionIdentifier inProcessSession:(OCProcessSession *)processSession;

@end

extern OCWaitConditionOption OCWaitConditionOptionPendingUserInteractionIdentifiers; //!< Array of identifiers of pending user interactions.

NS_ASSUME_NONNULL_END
