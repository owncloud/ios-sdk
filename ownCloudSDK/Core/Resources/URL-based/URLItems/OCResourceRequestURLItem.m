//
//  OCResourceRequestURLItem.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.09.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCResourceRequestURLItem.h"
#import "OCResource.h"
#import "NSDate+OCDateParser.h"

@implementation OCResourceRequestURLItem

+ (OCResourceVersion)daySpecificVersion
{
	return ([NSDate new].compactUTCStringDateOnly);
}

+ (OCResourceVersion)weekSpecificVersion
{
	NSDateComponents *components = [NSCalendar.autoupdatingCurrentCalendar components:NSCalendarUnitWeekOfYear|NSCalendarUnitYearForWeekOfYear fromDate:[NSDate new]];
	return ([NSString stringWithFormat:@"W%ldY%ld", components.weekOfYear, components.yearForWeekOfYear]);
}

+ (OCResourceVersion)monthSpecificVersion
{
	NSDateComponents *components = [NSCalendar.autoupdatingCurrentCalendar components:NSCalendarUnitWeekOfMonth|NSCalendarUnitYear fromDate:[NSDate new]];
	return ([NSString stringWithFormat:@"M%ldY%ld", components.month, components.year]);
}

+ (OCResourceVersion)yearSpecificVersion
{
	NSDateComponents *components = [NSCalendar.autoupdatingCurrentCalendar components:NSCalendarUnitYear fromDate:[NSDate new]];
	return ([NSString stringWithFormat:@"Y%ld", components.year]);
}

+ (instancetype)requestURLItem:(NSURL *)url identifier:(nullable OCResourceIdentifier)identifier version:(nullable OCResourceVersion)version structureDescription:(nullable OCResourceStructureDescription)structureDescription waitForConnectivity:(BOOL)waitForConnectivity changeHandler:(nullable OCResourceRequestChangeHandler)changeHandler
{
	if (identifier == nil) {
		identifier = url.absoluteString;
	}

	OCResourceRequestURLItem *request = [[self alloc] initWithType:OCResourceTypeURLItem identifier:identifier];

	request.version = version;
	request.structureDescription = structureDescription;

	request.reference = url;

	request.waitForConnectivity = waitForConnectivity;

	request.changeHandler = changeHandler;

	return (request);
}

- (NSURL *)url
{
	return (self.reference);
}

@end
