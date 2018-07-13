//
//  OCConnectionIssueChoice.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.06.18.
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

#import "OCConnectionIssueChoice.h"
#import "OCMacros.h"

@implementation OCConnectionIssueChoice

+ (instancetype)choiceWithType:(OCConnectionIssueChoiceType)type identifier:(NSString *)identifier label:(NSString *)label userInfo:(id<NSObject>)userInfo handler:(OCConnectionIssueChoiceHandler)handler
{
	OCConnectionIssueChoice *choice = [OCConnectionIssueChoice new];

	if (label == nil)
	{
		switch (type)
		{
			case OCConnectionIssueChoiceTypeCancel:
				label = OCLocalizedString(@"Cancel", @"");
			break;

			case OCConnectionIssueChoiceTypeDefault:
				label = OCLocalizedString(@"OK", @"");
			break;

			case OCConnectionIssueChoiceTypeDestructive:
				label = OCLocalizedString(@"Proceed", @"");
			break;

			case OCConnectionIssueChoiceTypeRegular:
			break;
		}
	}

	choice.type = type;
	choice.identifier = identifier;
	choice.label = label;
	choice.userInfo = userInfo;
	choice.choiceHandler = handler;

	return (choice);
}

+ (instancetype)choiceWithType:(OCConnectionIssueChoiceType)type label:(NSString *)label handler:(OCConnectionIssueChoiceHandler)handler;
{
	return ([self choiceWithType:type identifier:nil label:label userInfo:nil handler:handler]);
}

@end
