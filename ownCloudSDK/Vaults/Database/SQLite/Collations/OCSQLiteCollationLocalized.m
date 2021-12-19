//
//  OCSQLiteCollationLocalized.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 22.11.21.
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

#import "OCSQLiteCollationLocalized.h"

@implementation OCSQLiteCollationLocalized

+ (NSComparator)sortComparator
{
	static NSComparator sortComparator;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		sortComparator =  [^(NSString *string1, NSString *string2) {
			return ([string1 localizedStandardCompare:string2]);
		} copy];
	});

	return (sortComparator);
}

- (OCSQLiteCollationName)name
{
	return (OCSQLiteCollationNameLocalized);
}

- (NSComparisonResult)compare:(NSString *)string1 with:(NSString *)string2
{
	return ([string1 localizedStandardCompare:string2]);
}

@end

OCSQLiteCollationName OCSQLiteCollationNameLocalized = @"OCLOCALIZED";
