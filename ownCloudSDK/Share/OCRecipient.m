//
//  OCRecipient.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 01.03.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCRecipient.h"

@implementation OCRecipient

+ (instancetype)recipientWithUser:(OCUser *)user
{
	OCRecipient *recipient = [self new];

	recipient.type = OCRecipientTypeUser;
	recipient.user = user;

	return (recipient);
}

+ (instancetype)recipientWithGroup:(OCGroup *)group;
{
	OCRecipient *recipient = [self new];

	recipient.type = OCRecipientTypeGroup;
	recipient.group = group;

	return (recipient);
}

@end
