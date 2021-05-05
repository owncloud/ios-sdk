//
//  OCAuthenticationBrowserSessionMIBrowser.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.05.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

#import "OCAuthenticationBrowserSessionMIBrowser.h"

@implementation OCAuthenticationBrowserSessionMIBrowser

- (NSString *)plainCustomScheme
{
	return (@"mibrowser");
}

- (NSString *)secureCustomScheme
{
	return (@"mibrowsers");
}

@end
