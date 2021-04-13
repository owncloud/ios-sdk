//
//  OCIPNotificationCenter.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 21.10.18.
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class OCIPNotificationCenter;

typedef NSString* OCIPCNotificationName;
typedef void(^OCIPNotificationHandler)(OCIPNotificationCenter *notificationCenter, id observer, OCIPCNotificationName notificationName);

@interface OCIPNotificationCenter : NSObject
{
	CFNotificationCenterRef _darwinNotificationCenter;
	NSMutableDictionary <OCIPCNotificationName, NSMapTable<id, OCIPNotificationHandler> *> *_handlersByObserverByNotificationName;

	NSMutableDictionary <OCIPCNotificationName, NSNumber *> *_ignoreCountsByNotificationName;
}

@property(class,assign) BOOL loggingEnabled;

@property(strong,nonatomic,readonly,class) OCIPNotificationCenter *sharedNotificationCenter;

#pragma mark - Add/Remove notification observers
- (void)addObserver:(id)observer forName:(OCIPCNotificationName)name withHandler:(OCIPNotificationHandler)handler;

- (void)removeObserver:(id)observer forName:(OCIPCNotificationName)name;
- (void)removeAllObserversForName:(OCIPCNotificationName)name;

#pragma mark - Post notifications
- (void)postNotificationForName:(OCIPCNotificationName)name ignoreSelf:(BOOL)ignoreSelf;

@end

NS_ASSUME_NONNULL_END
