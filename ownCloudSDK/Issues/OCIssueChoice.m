//
//  OCIssueChoice.m
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

#import "OCIssueChoice.h"
#import "OCMacros.h"

@implementation OCIssueChoice

+ (instancetype)choiceWithType:(OCIssueChoiceType)type identifier:(NSString *)identifier label:(NSString *)label userInfo:(id<NSObject>)userInfo handler:(OCIssueChoiceHandler)handler
{
	OCIssueChoice *choice = [OCIssueChoice new];

	if (label == nil)
	{
		switch (type)
		{
			case OCIssueChoiceTypeCancel:
				label = OCLocalizedString(@"Cancel", @"");
			break;

			case OCIssueChoiceTypeDefault:
				label = OCLocalizedString(@"OK", @"");
			break;

			case OCIssueChoiceTypeDestructive:
				label = OCLocalizedString(@"Proceed", @"");
			break;

			case OCIssueChoiceTypeRegular:
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

+ (instancetype)choiceWithType:(OCIssueChoiceType)type label:(NSString *)label handler:(OCIssueChoiceHandler)handler;
{
	return ([self choiceWithType:type identifier:nil label:label userInfo:nil handler:handler]);
}

@end
