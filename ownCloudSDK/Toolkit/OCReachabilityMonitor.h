//
//  OCReachabilityMonitor.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.04.18.
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

#import <SystemConfiguration/SCNetworkReachability.h>
#import <Foundation/Foundation.h>

@interface OCReachabilityMonitor : NSObject
{
	NSString *_hostname;

	SCNetworkReachabilityRef _reachabilityRef;
	BOOL _enabled;
	BOOL _available;
}

@property(strong) NSString *hostname;

@property(assign,nonatomic) BOOL enabled;
@property(readonly,nonatomic) BOOL available;

- (instancetype)initWithHostname:(NSString *)hostname;

- (void)setEnabled:(BOOL)enabled withCompletionHandler:(dispatch_block_t)completionHandler;

@end

extern NSNotificationName OCReachabilityMonitorAvailabilityChangedNotification;
