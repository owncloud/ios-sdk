//
//  OCLogFileRecord.m
//  ownCloudSDK
//
//  Created by Michael Neuwert on 16.05.2019.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
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

#import "OCLogFileRecord.h"
#import <ownCloudSDK/OCAppIdentity.h>

@implementation OCLogFileRecord

@synthesize size=_size;
@synthesize creationDate=_creationDate;

- (instancetype)initWithURL:(NSURL*)url
{
	if ((self = [super init]) != nil)
	{
		_url = url;
		_size = -1;
	}

	return(self);
}

- (NSString*)name
{
	return _url.lastPathComponent;
}

- (int64_t)size
{
	if(_size < 0)
	{
		NSNumber* value;
		[_url getResourceValue:&value forKey:NSURLFileSizeKey error:nil];
		_size = [value longLongValue];
	}

	return _size;
}

- (NSDate*)creationDate
{
	if(_creationDate == nil)
	{
		NSDate *date;
		[_url getResourceValue:&date forKey:NSURLCreationDateKey error:nil];
		_creationDate = date;
	}
	return _creationDate;
}

@end
