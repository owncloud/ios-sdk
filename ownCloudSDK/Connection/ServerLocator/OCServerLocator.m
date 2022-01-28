//
//  OCServerLocator.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 08.11.21.
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

#import "OCServerLocator.h"
#import "NSError+OCError.h"
#import "OCExtensionManager.h"

@implementation OCServerLocator

- (NSError * _Nullable)locate
{
	return(nil);
}

#pragma mark - Instantiation from extension
+ (OCServerLocatorIdentifier)useServerLocatorIdentifier
{
	return ([self classSettingForOCClassSettingsKey:OCClassSettingsKeyServerLocatorUse]);
}

+ (OCServerLocator *)serverLocatorForIdentifier:(OCServerLocatorIdentifier)useLocatorIdentifier
{
	if (useLocatorIdentifier == nil) {
		return (nil);
	}

	OCServerLocator *serverLocator;
	NSError *error = nil;
	NSArray<OCExtensionMatch *> *matches;
	OCExtensionContext *context = [OCExtensionContext contextWithLocation:[OCExtensionLocation locationOfType:OCExtensionTypeServerLocator identifier:nil] requirements:nil preferences:nil];

	if ((matches = [OCExtensionManager.sharedExtensionManager provideExtensionsForContext:context error:&error]) != nil)
	{
		for (OCExtensionMatch *match in matches)
		{
			if ([match.extension.identifier isEqual:useLocatorIdentifier])
			{
				if ((serverLocator = [match.extension provideObjectForContext:context]) != nil)
				{
					break;
				}
			}
		}
	}

	return (serverLocator);
}

#pragma mark - Class settings
+ (OCClassSettingsIdentifier)classSettingsIdentifier
{
	return (OCClassSettingsIdentifierServerLocator);
}

+ (nullable NSDictionary<OCClassSettingsKey,id> *)defaultSettingsForIdentifier:(nonnull OCClassSettingsIdentifier)identifier
{
	return (@{
	});
}

+ (BOOL)classSettingsMetadataHasDynamicContentForKey:(OCClassSettingsKey)key
{
	return ([key isEqual:OCClassSettingsKeyServerLocatorUse]);
}

+ (OCClassSettingsMetadataCollection)classSettingsMetadata
{
	OCExtensionContext *context = [OCExtensionContext contextWithLocation:[OCExtensionLocation locationOfType:OCExtensionTypeServerLocator identifier:nil] requirements:nil preferences:nil];
	NSMutableDictionary<OCServerLocatorIdentifier, NSString *> *serverLocators = [NSMutableDictionary new];
	NSError *error;
	NSArray<OCExtensionMatch *> *matches;

	if ((matches = [OCExtensionManager.sharedExtensionManager provideExtensionsForContext:context error:&error]) != nil)
	{
		for (OCExtensionMatch *match in matches)
		{
			OCExtension *serverLocatorExtension = match.extension;
			OCExtensionMetadata metadata = serverLocatorExtension.extensionMetadata;

			NSString *description = metadata[OCExtensionMetadataKeyName];

			if (metadata[OCExtensionMetadataKeyDescription] != nil)
			{
				if (description == nil)
				{
					description = metadata[OCExtensionMetadataKeyDescription];
				}
				else
				{
					description = [description stringByAppendingFormat:@". %@", metadata[OCExtensionMetadataKeyDescription]];
				}
			}

			serverLocators[serverLocatorExtension.identifier] = (description != nil) ? description : @"";
		}
	}

	return (@{
		// Connection
		OCClassSettingsKeyServerLocatorUse : @{
			OCClassSettingsMetadataKeyType 		 : OCClassSettingsMetadataTypeString,
			OCClassSettingsMetadataKeyDescription 	 : @"Use Server Locator",
			OCClassSettingsMetadataKeyStatus	 : OCClassSettingsKeyStatusAdvanced,
			OCClassSettingsMetadataKeyCategory	 : @"Connection",
			OCClassSettingsMetadataKeyPossibleValues : serverLocators
		}
	});
}


@end

OCExtensionType OCExtensionTypeServerLocator = @"server-locator";
OCClassSettingsIdentifier OCClassSettingsIdentifierServerLocator = @"server-locator";
OCClassSettingsKey OCClassSettingsKeyServerLocatorUse = @"use";
