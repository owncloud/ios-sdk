//
//  OCPlatform.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 17.01.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCPlatform.h"
#import "OCAppIdentity.h"
#import "OCSQLiteDB.h"

@implementation OCPlatform

+ (OCPlatform *)current
{
	static OCPlatform *currentPlatform;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		currentPlatform = [OCPlatform new];
	});

	return (currentPlatform);
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_memoryConfiguration = OCPlatformMemoryConfigurationDefault;

		if ([OCAppIdentity.sharedAppIdentity.componentIdentifier isEqual:OCAppComponentIdentifierFileProviderExtension] ||
		    [OCAppIdentity.sharedAppIdentity.componentIdentifier isEqual:OCAppComponentIdentifierFileProviderUIExtension] ||
		    [OCAppIdentity.sharedAppIdentity.componentIdentifier isEqual:OCAppComponentIdentifierShareExtension])
		{
			_memoryConfiguration = OCPlatformMemoryConfigurationMinimum;
		}
	}

	return (self);
}

@end
