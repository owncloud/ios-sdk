//
//  OCItem+OCItemCreationDebugging.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 14.09.18.
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

#import "OCItem+OCItemCreationDebugging.h"

static BOOL sCreationHistoryEnabled = NO;

@implementation OCItem (OCItemCreationDebugging)

+ (BOOL)creationHistoryEnabled
{
	return (sCreationHistoryEnabled);
}

+ (void)setCreationHistoryEnabled:(BOOL)enabled
{
	sCreationHistoryEnabled = enabled;
}

#pragma mark - Capture call stack
- (void)_captureCallstack
{
	if (sCreationHistoryEnabled)
	{
		_creationHistory = [[[NSDate date] description] stringByAppendingFormat:@" call stack:\n%@", [[NSThread callStackSymbols] componentsJoinedByString:[NSString stringWithFormat:@"\n"]]];
	}
}

- (NSString *)creationHistory
{
	return (_creationHistory);
}

@end
