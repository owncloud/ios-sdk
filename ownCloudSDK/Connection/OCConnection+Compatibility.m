//
//  OCConnection+Compatibility.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 25.04.18.
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

#import "OCConnection.h"
#import "NSString+OCVersionCompare.h"

@implementation OCConnection (Compatibility)

#pragma mark - Version
- (NSString *)serverVersion
{
	return (_serverStatus[@"version"]);
}

- (NSString *)serverVersionString
{
	return (_serverStatus[@"versionstring"]);
}

- (NSString *)serverProductName
{
	return (_serverStatus[@"productname"]);
}

- (NSString *)serverEdition
{
	return (_serverStatus[@"edition"]);
}

- (NSString *)serverLongProductVersionString
{
	return ([NSString stringWithFormat:@"%@ %@ %@", _serverStatus[@"productname"], _serverStatus[@"edition"], _serverStatus[@"version"]]);
}

#pragma mark - API Switches
- (BOOL)runsServerVersionOrHigher:(NSString *)version
{
	return ([self.serverVersion compareVersionWith:version] >= NSOrderedSame);
}

- (BOOL)supportsPreviewAPI
{
	return ([self runsServerVersionOrHigher:@"10.0.9"]);
}

@end
