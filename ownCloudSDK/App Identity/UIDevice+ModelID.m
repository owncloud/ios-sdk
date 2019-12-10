//
//  UIDevice+ModelID.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 11.11.19.
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

#import "UIDevice+ModelID.h"
#include <sys/sysctl.h>

@implementation UIDevice (ModelID)

- (NSString *)ocModelIdentifier
{
	static NSString *modelIdentifier;

	if (modelIdentifier == nil)
	{
		size_t size = 0;

		sysctlbyname("hw.machine", NULL, &size, NULL, 0);

		if (size > 0)
		{
			void *hwModel;

			if ((hwModel = calloc(1, size+1)) != NULL)
			{
				sysctlbyname("hw.machine", hwModel, &size, NULL, 0);

				modelIdentifier = [[NSString alloc] initWithUTF8String:hwModel];

				free(hwModel);
			}
		}
	}

	return (modelIdentifier);
}

@end
