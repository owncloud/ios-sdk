//
//  NSString+OCPath.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 17.06.18.
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

#import "NSString+OCPath.h"

@implementation NSString (OCPath)

- (OCPath)parentPath
{
	return ([[self stringByDeletingLastPathComponent] normalizedDirectoryPath]);
}

- (BOOL)isRootPath
{
	return ([self isEqualToString:@"/"]);
}

- (OCPath)normalizedDirectoryPath
{
	if (![self hasSuffix:@"/"])
	{
		return ([self stringByAppendingString:@"/"]);
	}

	return (self);
}

- (OCPath)pathForSubdirectoryWithName:(NSString *)subDirectoryName
{
	return ([[self stringByAppendingPathComponent:subDirectoryName] normalizedDirectoryPath]);
}

@end
