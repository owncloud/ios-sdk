//
//  OCVault.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.02.18.
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

#import "OCVault.h"
#import "OCAppIdentity.h"

@implementation OCVault

@synthesize uuid;

@synthesize database;

@synthesize rootURL;

#pragma mark - Init
- (instancetype)init
{
	return (nil);
}

- (instancetype)initWithBookmark:(OCBookmark *)bookmark
{
	if ((self = [super init]) != nil)
	{
		_uuid = bookmark.uuid;
	}
	
	return (self);
}

- (NSURL *)rootURL
{
	if (_rootURL == nil)
	{
		_rootURL = [[[OCAppIdentity sharedAppIdentity] appGroupContainerURL] URLByAppendingPathComponent:[self.uuid UUIDString]];
	}
	
	return (_rootURL);
}

@end
