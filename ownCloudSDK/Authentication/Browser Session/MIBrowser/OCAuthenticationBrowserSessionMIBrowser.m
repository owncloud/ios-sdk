//
//  OCAuthenticationBrowserSessionMIBrowser.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.05.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

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
