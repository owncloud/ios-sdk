//
//  OCCoreProxy.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 16.09.19.
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

#import "OCCoreProxy.h"
#import "OCLogger.h"
#import <objc/runtime.h>

@implementation OCCoreProxy

- (instancetype)initWithCore:(OCCore *)core
{
	_core = core;
	_bookmarkUUID = core.bookmark.uuid;

	return (self);
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
	if (_core == nil)
	{
		NSArray<OCLogTagName> *tags = @[ @"ZOMBIE" ];
		OCRLogError(tags, @"Zombie core %@: call to %s via %@", _bookmarkUUID, sel_getName(selector), [NSThread callStackSymbols]);
	}
	return ([_core methodSignatureForSelector:selector]);
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
	if (_core == nil)
	{
		NSArray<OCLogTagName> *tags = @[ @"ZOMBIE" ];
		OCRLogError(tags, @"Zombie core %@: invocation %@ via %@", _bookmarkUUID, invocation, [NSThread callStackSymbols]);
		return;
	}

	[invocation setTarget:_core];
	[invocation invoke];
}

+ (BOOL)conformsToProtocol:(Protocol *)protocol
{
	return ([[OCCore class] conformsToProtocol:protocol]);
}

- (BOOL)conformsToProtocol:(Protocol *)protocol
{
	if (_core == nil)
	{
		NSArray<OCLogTagName> *tags = @[ @"ZOMBIE" ];
		OCRLogError(tags, @"Zombie core %@: protocol conformance check for %@ via %@", _bookmarkUUID, protocol, [NSThread callStackSymbols]);
		return(NO);
	}

	return ([_core conformsToProtocol:protocol]);
}

@end
