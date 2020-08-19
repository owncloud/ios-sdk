//
//  OCClassSettingsFlatSourcePropertyList.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 22.03.18.
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

#import "OCLogger.h"
#import "OCClassSettingsFlatSourcePropertyList.h"

@interface OCClassSettingsFlatSourcePropertyList ()
{
	NSDictionary<NSString *, id> *_flatSettingsDictionary;
}

@end

@implementation OCClassSettingsFlatSourcePropertyList

- (instancetype)initWithURL:(NSURL *)propertyListURL
{
	if ((self = [super init]) != nil)
	{
		NSError *error = nil;

		if ((_flatSettingsDictionary = [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfURL:propertyListURL] options:0 format:NULL error:&error]) == nil)
		{
			OCLogError(@"Error reading %@: %@", propertyListURL, OCLogPrivate(error));
		}
		else
		{
			if (![_flatSettingsDictionary isKindOfClass:[NSDictionary class]])
			{
				OCLogError(@"Error in %@: root object is not a dictionary: %@", propertyListURL, OCLogPrivate(_flatSettingsDictionary));

				_flatSettingsDictionary = nil;
			}
		}

		[self parseFlatSettingsDictionary];
	}

	return (self);
}

- (NSDictionary<NSString *,id> *)flatSettingsDictionary
{
	return (_flatSettingsDictionary);
}

@end
