//
//  OCLockRequest.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.02.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCLockRequest.h"

@implementation OCLockRequest

- (instancetype)initWithResourceIdentifier:(OCLockResourceIdentifier)resourceIdentifier acquiredHandler:(OCLockAcquiredHandler)acquiredHandler
{
	if ((self = [super init]) != nil)
	{
		_resourceIdentifier = resourceIdentifier;
		self.acquiredHandler = acquiredHandler;
	}

	return (self);
}

- (void)invalidate
{
	self.invalidated = YES;
}

@end
