//
//  OCIdentity+GraphAPI.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 16.12.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCIdentity+GraphAPI.h"
#import "GASharePointIdentitySet.h"
#import "GAIdentitySet.h"
#import "GAIdentity.h"

@implementation OCIdentity (GraphAPI)

+ (instancetype)identityFromGAIdentitySet:(GAIdentitySet *)identitySet
{
	if (identitySet.user != nil)
	{
		return ([OCIdentity identityWithUser:[OCUser userWithGraphIdentity:identitySet.user]]);
	}

	if (identitySet.group != nil)
	{
		return ([OCIdentity identityWithGroup:[OCGroup groupWithGraphIdentity:identitySet.group]]);
	}

	return (nil);
}

+ (instancetype)identityFromGASharePointIdentitySet:(GASharePointIdentitySet *)identitySet
{
	if (identitySet.user != nil)
	{
		return ([OCIdentity identityWithUser:[OCUser userWithGraphIdentity:identitySet.user]]);
	}

	if (identitySet.group != nil)
	{
		return ([OCIdentity identityWithGroup:[OCGroup groupWithGraphIdentity:identitySet.group]]);
	}

	return (nil);
}

- (GAIdentitySet *)gaIdentitySet
{
	GAIdentitySet *identitySet = [GAIdentitySet new];
	identitySet.user = (self.user != nil) ? self.user.gaIdentity : nil;
	identitySet.group = (self.group != nil) ? self.group.gaIdentity : nil;
	return (identitySet);
}

- (GAIdentity *)gaIdentity
{
	return (self.user != nil) ?
			self.user.gaIdentity :
		((self.group != nil) ?
			self.group.gaIdentity :
			nil);
}

@end
