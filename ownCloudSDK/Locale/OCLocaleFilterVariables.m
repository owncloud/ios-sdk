//
//  OCLocaleFilterVariables.m
//  OCLocaleFilterVariables
//
//  Created by Felix Schwarz on 16.10.21.
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

#import <UIKit/UIKit.h>

#import "OCLocaleFilterVariables.h"
#import "OCAppIdentity.h"
#import "UIDevice+ModelID.h"

@interface OCLocaleFilterVariables()
{
	NSMutableDictionary<NSString *, OCLocaleFilterVariableSource> *_sourcesByVariableName;
	NSMutableDictionary<NSString *, NSString *> *_valueByVariableName;
}

@end

@implementation OCLocaleFilterVariables

#pragma mark - Shared
+ (OCLocaleFilterVariables *)shared
{
	static dispatch_once_t onceToken;
	static OCLocaleFilterVariables *sharedInstance = nil;

	dispatch_once(&onceToken, ^{
		sharedInstance = [OCLocaleFilterVariables new];

		[sharedInstance setVariable:@"app.name" 	value:OCAppIdentity.sharedAppIdentity.appDisplayName];
		[sharedInstance setVariable:@"app.process" 	value:OCAppIdentity.sharedAppIdentity.appName];
		[sharedInstance setVariable:@"app.version" 	value:OCAppIdentity.sharedAppIdentity.appVersion];
		[sharedInstance setVariable:@"app.build" 	value:OCAppIdentity.sharedAppIdentity.appBuildNumber];

		[sharedInstance setVariable:@"device.model" 	value:UIDevice.currentDevice.model];
		[sharedInstance setVariable:@"device.model-id" 	value:UIDevice.currentDevice.ocModelIdentifier];
		[sharedInstance setVariable:@"os.name"  	value:UIDevice.currentDevice.systemName];
		[sharedInstance setVariable:@"os.version"  	value:UIDevice.currentDevice.systemVersion];
	});

	return (sharedInstance);
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_sourcesByVariableName = [NSMutableDictionary new];
	}

	return (self);
}

- (void)setVariable:(NSString *)variableName value:(NSString *)value
{
	variableName = [[NSString alloc] initWithFormat:@"{{%@}}", variableName];

	if ((value != nil) && (_valueByVariableName == nil))
	{
		_valueByVariableName = [NSMutableDictionary new];
	}

	_valueByVariableName[variableName] = value;

	if (_valueByVariableName.count == 0)
	{
		_valueByVariableName = nil;
	}
}

- (void)setVariable:(NSString *)variableName source:(OCLocaleFilterVariableSource)source
{
	variableName = [[NSString alloc] initWithFormat:@"{{%@}}", variableName];

	if ((source != nil) && (_sourcesByVariableName == nil))
	{
		_sourcesByVariableName = [NSMutableDictionary new];
	}

	_sourcesByVariableName[variableName] = [source copy];

	if (_sourcesByVariableName.count == 0)
	{
		_sourcesByVariableName = nil;
	}
}

- (NSString *)applyToLocalizedString:(NSString *)localizedString withOriginalString:(NSString *)originalString options:(OCLocaleOptions)options
{
	if (_valueByVariableName != nil)
	{
		for (NSString *variableName in _valueByVariableName)
		{
			localizedString = [localizedString stringByReplacingOccurrencesOfString:variableName withString:_valueByVariableName[variableName]];
		}
	}

	if (_sourcesByVariableName != nil)
	{
		for (NSString *variableName in _sourcesByVariableName)
		{
			NSRange range;

			do {
				range = [localizedString rangeOfString:variableName];

				if (range.location != NSNotFound)
				{
					OCLocaleFilterVariableSource source = _sourcesByVariableName[variableName];
					NSString *computedReplacement;

					if ((computedReplacement = source()) != nil)
					{
						localizedString = [localizedString stringByReplacingCharactersInRange:range withString:computedReplacement];
					}
					else
					{
						// Avoid infinite while-loop
						break;
					}
				}
			} while(range.location != NSNotFound);
		}
	}

	NSDictionary<NSString *, NSString *> *customValuesByVariables = nil;

	if ((customValuesByVariables = options[OCLocaleOptionKeyVariables]) != nil) {
		for (NSString *variableName in customValuesByVariables) {
			localizedString = [localizedString stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"{{%@}}", variableName] withString:customValuesByVariables[variableName]];
		}
	}

	return (localizedString);
}

@end

OCLocaleOptionKey OCLocaleOptionKeyVariables = @"variables";
