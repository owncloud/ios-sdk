//
//  OCLogSource.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 01.11.18.
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

#import "OCLogSource.h"

@implementation OCLogSource

#pragma mark - Init
- (instancetype)initWithName:(NSString *)name logger:(OCLogger *)logger
{
	if ((self = [super init]) != nil)
	{
		_name = name;
		_logger = logger;
	}

	return (self);
}

#pragma mark - Start / Stop source
- (void)start
{
}

- (void)stop
{
}

@end
