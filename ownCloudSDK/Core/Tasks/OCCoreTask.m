//
//  OCCoreTask.m
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

#import "OCCoreTask.h"

@implementation OCCoreTask

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_cachedSet = [OCCoreTaskSet new];
		_retrievedSet = [OCCoreTaskSet new];
	}

	return(self);
}

- (instancetype)initWithPath:(OCPath)path
{
	if ((self = [self init]) != nil)
	{
		_path = path;
	}

	return (self);
}

@end
