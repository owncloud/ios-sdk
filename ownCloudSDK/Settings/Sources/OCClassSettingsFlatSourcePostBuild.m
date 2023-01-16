//
//  OCClassSettingsFlatSourcePostBuild.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 16.01.23.
//  Copyright © 2023 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2023, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCClassSettingsFlatSourcePostBuild.h"
#import "OCLogger.h"

@implementation OCClassSettingsFlatSourcePostBuild

#pragma mark - Class Settings support
+ (OCClassSettingsIdentifier)classSettingsIdentifier
{
	return (OCClassSettingsIdentifierPostBuildSettings);
}

+ (NSDictionary<OCClassSettingsKey,id> *)defaultSettingsForIdentifier:(OCClassSettingsIdentifier)identifier
{
	return (@{
		OCClassSettingsKeyPostBuildAllowedFlatIdentifiers : @[ ]
	});
}

+ (OCClassSettingsFlatSourcePostBuild *)sharedPostBuildSettings
{
	static dispatch_once_t onceToken;
	static OCClassSettingsFlatSourcePostBuild *sharedSource;

	dispatch_once(&onceToken, ^{
		sharedSource = [OCClassSettingsFlatSourcePostBuild new];
	});

	return (sharedSource);
}

+ (OCClassSettingsMetadataCollection)classSettingsMetadata
{
	return (@{
		// Allowed Post Build Flat Identifiers
		OCClassSettingsKeyPostBuildAllowedFlatIdentifiers : @{
			OCClassSettingsMetadataKeyType 		: OCClassSettingsMetadataTypeStringArray,
			OCClassSettingsMetadataKeyDescription 	: @"List of settings (as flat identifiers) that are allowed to be changed post-build via the app's URL scheme. Including a value of \"*\" allows any setting to be changed. Defaults to an empty array (equalling not allowed). ",
			OCClassSettingsMetadataKeyStatus	: OCClassSettingsKeyStatusAdvanced,
			OCClassSettingsMetadataKeyCategory	: @"Security"
		},
	});
}

#pragma mark - File URL & loading
- (NSURL *)postBuildSettingsFileURL
{
	return ([OCAppIdentity.sharedAppIdentity.appGroupContainerURL URLByAppendingPathComponent:@"postBuildSettings.plist"]);
}

- (NSMutableDictionary<OCClassSettingsFlatIdentifier,id> *)_settingsDict
{
	NSError *error = nil;
	NSMutableDictionary<OCClassSettingsFlatIdentifier,id> *settingsDict;

	settingsDict = (id) [NSMutableDictionary dictionaryWithContentsOfURL:self.postBuildSettingsFileURL error:&error];

	if (settingsDict == nil)
	{
		settingsDict = [NSMutableDictionary new];
	}

	return (settingsDict);
}

#pragma mark - Access and modification
- (nullable id)valueForFlatIdentifier:(OCClassSettingsFlatIdentifier)flatID
{
	return ([[self _settingsDict] objectForKey:flatID]);
}

- (nullable NSError *)setValue:(nullable id)value forFlatIdentifier:(OCClassSettingsFlatIdentifier)flatID
{
	NSMutableDictionary<OCClassSettingsFlatIdentifier,id> *settingsDict = [self _settingsDict];
	NSError *error = nil;
	NSArray<OCClassSettingsFlatIdentifier> *allowedKeys = [self classSettingForOCClassSettingsKey:OCClassSettingsKeyPostBuildAllowedFlatIdentifiers];

	if ( (allowedKeys == nil) ||
	    ((allowedKeys != nil) && ![allowedKeys containsObject:flatID] && ![allowedKeys containsObject:@"*"])
	   )
	{
		OCTLogError(@[@"PostBuild"], @"Change not allowed: %@=%@", flatID, value);
		return(OCErrorWithDescription(OCErrorInternal, ([NSString stringWithFormat:@"%@ not allowed to be modified post-build.", flatID])));
	}

	settingsDict[flatID] = value;

	[settingsDict writeToURL:self.postBuildSettingsFileURL error:&error];

	if (error != nil)
	{
		OCTLogError(@[@"PostBuild"], @"Error saving %@=%@ to %@", flatID, value, self.postBuildSettingsFileURL);
	}
	else
	{
		OCTLog(@[@"PostBuild"], @"Saved %@=%@", flatID, value);
	}

	return (error);
}

- (nullable NSError *)clear
{
	NSError *error = nil;

	if (![NSFileManager.defaultManager removeItemAtURL:self.postBuildSettingsFileURL error:&error])
	{
		return (error);
	}

	return (nil);
}

#pragma mark - OCClassSettingsFlatSource subclassing
- (OCClassSettingsSourceIdentifier)settingsSourceIdentifier
{
	return (OCClassSettingsSourceIdentifierPostBuild);
}

- (nullable NSDictionary <OCClassSettingsFlatIdentifier, id> *)flatSettingsDictionary
{
	// Maybe this is not possible as we can't request a setting before the shared class settings instance isn't set up ?!

//	NSArray<OCClassSettingsFlatIdentifier> *allowedKeys;
//
//	if ((allowedKeys = [self classSettingForOCClassSettingsKey:OCClassSettingsKeyPostBuildAllowedFlatIdentifiers]) &&
//	    (allowedKeys.count > 0))
//	{
//		// Make sure only those settings are applied that are allowed at the time
//		return ([[self _settingsDict] dictionaryWithValuesForKeys:allowedKeys]);
//	}
//
//	return (nil);

	// Return full chontents of post-build settings file
	return ([self _settingsDict]);
}

@end

OCClassSettingsSourceIdentifier OCClassSettingsSourceIdentifierPostBuild = @"pb";

OCClassSettingsIdentifier OCClassSettingsIdentifierPostBuildSettings = @"post-build";
OCClassSettingsKey OCClassSettingsKeyPostBuildAllowedFlatIdentifiers = @"allowed-flat-identifiers";
