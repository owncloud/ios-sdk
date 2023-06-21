//
//  OCMacros.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 03.03.18.
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

#ifndef OCMacros_h
#define OCMacros_h

#import "OCLocale.h"

#define OCLocalizedString(key,comment) [OCLocale localizeString:key bundleOfClass:[self class]]
#define OCLocalized(key) [OCLocale localizeString:key bundleOfClass:[self class]]
#define OCLocalizedViaLocalizationBundle(key) [OCLocale localizeString:key bundle:localizationBundle]
#define OCLocalizedFormat(key,variables) [OCLocale localizeString:key bundleOfClass:[self class] options:@{ OCLocaleOptionKeyVariables : variables }]

// Macros to simplify usage of dispatch groups (and allow switching to more efficient mechanisms in the future)
#define OCWaitInit(label) 	  	dispatch_group_t label = dispatch_group_create()
#define OCWaitInitAndStartTask(label) 	dispatch_group_t label = dispatch_group_create(); \
				  	dispatch_group_enter(label)
#define OCWaitWillStartTask(label)	dispatch_group_enter(label)
#define OCWaitDidFinishTask(label)	dispatch_group_leave(label)
#define OCWaitForCompletion(label)	dispatch_group_wait(label, DISPATCH_TIME_FOREVER)
#define OCWaitForCompletionWithTimeout(label,timeout)	dispatch_group_wait(label, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)))
#define OCWaitOnCompletion(label,queue,block) dispatch_group_notify(label, queue, block);

// Macros to simplify the use of async APIs in a synchronous fashion
#define OCSyncExec(label,code)	dispatch_semaphore_t label = dispatch_semaphore_create(0); \
				code \
				dispatch_semaphore_wait(label, DISPATCH_TIME_FOREVER)

#define OCSyncExecDone(label)	dispatch_semaphore_signal(label)

#define OCTypedCast(var,className) ([var isKindOfClass:[className class]] ? ((className *)var) : nil)
#define OCConformanceCast(var,protocolName) ([var conformsToProtocol:@protocol(protocolName)] ? ((id<protocolName>)var) : nil)

// nil-aware comparisons
#define OCNANotEqual(a,b) ((![(a) isEqual:(b)]) && ((a) != (b)))
#define OCNAIsEqual(a,b)  (([(a) isEqual:(b)]) || ((a) == (b)))

// debug description
#define OCExpandVar(var) ((_##var!=nil) ? [@", " #var ": " stringByAppendingString:_##var.description] : @"")

// nil -> NSNull wrapper/unwrapper
#define OCNullProtect(object) (((object)!=nil) ? (object) : NSNull.null)
#define OCNullResolved(object) ([(object) isKindOfClass:[NSNull class]] ? nil : (object))

#endif /* OCMacros_h */
