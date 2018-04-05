//
//  OCReachabilityMonitor.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.04.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

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

@end

extern NSNotificationName OCReachabilityMonitorAvailabilityChangedNotification;
