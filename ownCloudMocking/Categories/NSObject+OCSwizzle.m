//
//  NSObject+OCSwizzle.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 11.07.18.
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

#import "NSObject+OCSwizzle.h"
#import <objc/runtime.h>

@implementation NSObject (OCSwizzle)

+ (void)exchangeInstanceMethodImplementationOfClass:(Class)origClass selector:(SEL)origSelector withSelector:(SEL)exchangeSelector ofClass:(Class)exchangeClass
{
	Method origMethod, exchangeMethod;

	if (((origMethod = class_getInstanceMethod(origClass, origSelector)) != NULL) &&
	    ((exchangeMethod = class_getInstanceMethod(exchangeClass, exchangeSelector)) != NULL))
	{
		if (class_addMethod(origClass, origSelector, method_getImplementation(exchangeMethod), method_getTypeEncoding(exchangeMethod)))
		{
			class_replaceMethod(origClass, exchangeSelector, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
		}
		else
		{
			method_exchangeImplementations(origMethod, exchangeMethod);
		}
	}
}

+ (void)exchangeClassMethodImplementationOfClass:(Class)origClass selector:(SEL)origSelector withSelector:(SEL)exchangeSelector ofClass:(Class)exchangeClass
{
	Method origMethod, exchangeMethod;

	if (((origMethod = class_getClassMethod(origClass, origSelector)) != NULL) &&
	    ((exchangeMethod = class_getClassMethod(exchangeClass, exchangeSelector)) != NULL))
	{
		origClass = object_getClass((id)origClass);

		if (class_addMethod(origClass, origSelector, method_getImplementation(exchangeMethod), method_getTypeEncoding(exchangeMethod)))
		{
			class_replaceMethod(origClass, exchangeSelector, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
		}
		else
		{
			method_exchangeImplementations(origMethod, exchangeMethod);
		}
	}
}

@end
