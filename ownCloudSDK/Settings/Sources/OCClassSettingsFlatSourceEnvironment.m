//
//  OCClassSettingsFlatSourceEnvironment.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 31.10.18.
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

/*
	Example of env variables with "oc:" prefix
	oc:app.show-beta-warning=false
*/

#import "OCClassSettingsFlatSourceEnvironment.h"

@interface OCClassSettingsFlatSourceEnvironment ()
{
	NSString *_prefix;
	NSMutableDictionary<NSString *, id> *_flatSettingsDictionary;
}

@end

@implementation OCClassSettingsFlatSourceEnvironment

- (OCClassSettingsSourceIdentifier)settingsSourceIdentifier
{
	return (OCClassSettingsSourceIdentifierEnvironment);
}

- (instancetype)initWithPrefix:(NSString *)prefix
{
	if ((self = [super init]) != nil)
	{
		_prefix = prefix;

		[self parseFlatSettingsDictionary];
	}

	return(self);
}

- (NSDictionary<OCClassSettingsFlatIdentifier,id> *)flatSettingsDictionary
{
	if ((_prefix != nil) && (_flatSettingsDictionary == nil))
	{
		NSDictionary<NSString*, NSString*> *environmentVariables;

		if ((environmentVariables = [[NSProcessInfo processInfo] environment]) != nil)
		{
			if ((_flatSettingsDictionary = [NSMutableDictionary new]) != nil)
			{
				[environmentVariables enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull varName, NSString * _Nonnull valueString, BOOL * _Nonnull stop) {
					if ([varName hasPrefix:self->_prefix])
					{
						id value = nil;
						static NSString *stringPrefix = @"string:";
						static NSString *integerPrefix = @"int:";
						static NSString *boolPrefix = @"bool:";
						static NSString *arrayPrefix = @"[";
						static NSString *arraySuffix = @"]";
						static NSString *dictionaryPrefix = @"{";
						static NSString *dictionarySuffix = @"}";
						NSString *settingsKey;

						// Remove prefix
						settingsKey = [varName substringFromIndex:self->_prefix.length];

						// Determine type:
						// - strings: starting and ending with " or string: prefix
						// - integer: not starting with " - or staring with an int: prefix
						// - bool: valid values are true and false (not enclosed in ""), bool:true and bool:false

						// Check for prefixes
						if ([valueString hasPrefix:stringPrefix])
						{
							// String prefix
							value = [valueString substringFromIndex:stringPrefix.length];
						}
						else if ([valueString hasPrefix:integerPrefix])
						{
							// Integer prefix
							value = @([[valueString substringFromIndex:integerPrefix.length] integerValue]);
						}
						else if ([valueString hasPrefix:boolPrefix])
						{
							// Bool prefix
							if ([valueString isEqualToString:@"bool:true"])
							{
								value = @(YES);
							}
							else if ([valueString isEqualToString:@"bool:false"])
							{
								value = @(NO);
							}
						}
						else if ([valueString hasPrefix:arrayPrefix] && [valueString hasSuffix:arraySuffix])
						{
							// Array pre- und suffix
							value = [[valueString substringWithRange:NSMakeRange(1, valueString.length-2)] componentsSeparatedByString:@","];
						}
						else if ([valueString hasPrefix:dictionaryPrefix] && [valueString hasSuffix:dictionarySuffix])
						{
							// JSON Dictionary
							value = [NSJSONSerialization JSONObjectWithData:[valueString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
						}

						// Try to detect type
						if (value == nil)
						{
							// Bool
							if ([valueString isEqualToString:@"true"])
							{
								value = @(YES);
							}
							else if ([valueString isEqualToString:@"false"])
							{
								value = @(NO);
							}
						}

						if (value == nil)
						{
							// String and numbers
							if ([valueString hasPrefix:@"\""] && [valueString hasSuffix:@"\""])
							{
								// "String"
								value = [valueString substringWithRange:NSMakeRange(1, valueString.length-2)];
							}
							else
							{
								// Assume integer if first char is any of -1234567890
								if ([valueString hasPrefix:@"-"] || [valueString hasPrefix:@"1"] || [valueString hasPrefix:@"2"] || [valueString hasPrefix:@"3"] || [valueString hasPrefix:@"4"] || [valueString hasPrefix:@"5"] || [valueString hasPrefix:@"6"] || [valueString hasPrefix:@"7"]  || [valueString hasPrefix:@"8"] || [valueString hasPrefix:@"9"] || [valueString hasPrefix:@"0"])
								{
									value = @([valueString integerValue]);
								}
							}
						}

						// Populate flat settings
						if (value != nil)
						{
							self->_flatSettingsDictionary[settingsKey] = value;
						}
						else
						{
							NSLog(@"Environment variable %@=%@ could not be parsed.", varName, valueString);
						}
					}
				}];
			}
		}
	}

	return (_flatSettingsDictionary);
}

@end

OCClassSettingsSourceIdentifier OCClassSettingsSourceIdentifierEnvironment = @"env";
