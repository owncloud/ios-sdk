//
//  OCChecksum+TUS.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.02.21.
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

#import "OCChecksum+TUS.h"

@implementation OCChecksum (TUS)

+ (instancetype)checksumFromTUSString:(OCTUSChecksumString)tusString
{
	return ([[self alloc] initFromTUSString:tusString]);
}

- (instancetype)initFromTUSString:(OCTUSChecksumString)tusString
{
	if ((self = [super init]) != nil)
	{
		NSArray <NSString *> *components;

		if ((components = [tusString componentsSeparatedByString:@" "]) != nil)
		{
			if (components.count == 2)
			{
				_algorithmIdentifier = components.firstObject.uppercaseString;
				_checksum = components.lastObject;
			}
			else
			{
				self = nil;
			}
		}
	}

	return (self);
}

- (OCTUSChecksumString)tusString
{
	return ([NSString stringWithFormat:@"%@ %@", self.algorithmIdentifier.lowercaseString, self.checksum]);
}

@end
