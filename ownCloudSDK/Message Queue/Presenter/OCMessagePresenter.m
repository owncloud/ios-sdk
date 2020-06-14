//
//  OCMessagePresenter.m
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

#import "OCMessagePresenter.h"
#import "OCAppIdentity.h"

@implementation OCMessagePresenter

- (OCMessagePresenterComponentSpecificIdentifier)componentSpecificIdentifier
{
	return ([OCAppIdentity.sharedAppIdentity.componentIdentifier stringByAppendingFormat:@":%@", self.identifier]);
}

- (OCMessagePresentationPriority)presentationPriorityFor:(OCMessage *)message
{
	return (OCMessagePresentationPriorityWontPresent);
}

- (void)present:(OCMessage *)message completionHandler:(void(^)(OCMessagePresentationResult result, OCMessageChoice * _Nullable choice))completionHandler
{
	completionHandler(OCMessagePresentationResultDidNotPresent, nil);
}

- (void)endPresentationOfMessage:(OCMessage *)message
{
}

@end
