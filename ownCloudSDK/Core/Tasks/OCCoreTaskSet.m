//
//  OCCoreTaskSet.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 02.04.18.
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

#import "OCCoreTaskSet.h"

@implementation OCCoreTaskSet

- (void)updateWithError:(NSError *)error items:(NSArray <OCItem *> *)items
{
	self.error = error;

	if (error != nil)
	{
		self.state = OCCoreTaskSetStateFailed;
	}
	else
	{
		self.state = OCCoreTaskSetStateSuccess;
		self.items = items;
	}
}

@end
