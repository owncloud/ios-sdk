//
//  OCDAVRawResponse.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.06.21.
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

#import "OCDAVRawResponse.h"

@implementation OCDAVRawResponse

#pragma mark - NSSecureCoding
+ (BOOL)supportsSecureCoding
{
	return(YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [self init]) != nil)
	{
		_responseDataURL = [decoder decodeObjectOfClass:NSURL.class forKey:@"responseDataURL"];
		_basePath = [decoder decodeObjectOfClass:NSString.class forKey:@"basePath"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_responseDataURL forKey:@"responseDataURL"];
	[coder encodeObject:_basePath forKey:@"basePath"];
}

@end

