//
//  NSArray+ObjCRuntime.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 30.10.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "NSArray+ObjCRuntime.h"
#import <objc/runtime.h>

@implementation NSArray (OCObjCRuntime)

+ (NSArray<Class> *)classesImplementing:(Protocol *)protocol
{
	NSMutableArray<Class> *implementingClasses = [NSMutableArray new];
	int classCount;

	if ((classCount = objc_getClassList(NULL, 0)) > 0)
	{
		Class *classList;

		if ((classList = (Class *)malloc(classCount * sizeof(Class))) != NULL)
		{
			classCount = objc_getClassList(classList, classCount);

			for (int i=0; i<classCount; i++)
			{
				Class inspectClass = classList[i];

				if (class_getClassMethod(inspectClass, @selector(conformsToProtocol:)) != NULL)
				{
					if ([inspectClass conformsToProtocol:protocol])
					{
						[implementingClasses addObject:inspectClass];
					}
				}
			}

			free(classList);
		}
	}

	return (implementingClasses);
}

@end
