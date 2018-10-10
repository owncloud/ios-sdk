//
//  OCExtensionMatch.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 23.08.18.
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

#import "OCExtensionMatch.h"

@implementation OCExtensionMatch

- (instancetype)initWithExtension:(OCExtension *)extension priority:(OCExtensionPriority)priority
{
	if ((self = [super init]) != nil)
	{
		_extension = extension;
		_priority = priority;
	}

	return(self);
}

@end
