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

- (instancetype)initWithName:(NSString*)name creationDate:(NSDate*)date fileSize:(int64_t)size
{
	if ((self = [super init]) != nil)
	{
		_name = name;
		_creationDate = date;
		_size = size;
	}

	return(self);
}

- (NSString*)fullPath
{
	NSString *logDirectoryPath = [[OCAppIdentity.sharedAppIdentity appGroupLogsContainerURL] path];
	return [logDirectoryPath stringByAppendingPathComponent:_name];
}

@end
