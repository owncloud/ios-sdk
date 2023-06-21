//
//  OCItemThumbnail.m
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

#import "OCItemThumbnail.h"
#import "UIImage+OCTools.h"

@implementation OCItemThumbnail

@synthesize itemVersionIdentifier = _itemVersionIdentifier;

@synthesize specID = _specID;

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];

	[coder encodeObject:_itemVersionIdentifier    	forKey:@"itemVersionIdentifier"];
	[coder encodeObject:_specID   			forKey:@"specID"];
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super initWithCoder:decoder]) != nil)
	{
		_itemVersionIdentifier = [decoder decodeObjectOfClass:[OCItemVersionIdentifier class] forKey:@"itemVersionIdentifier"];
		_specID = [decoder decodeObjectOfClass:[NSString class] forKey:@"specID"];
	}

	return (self);
}

@end
