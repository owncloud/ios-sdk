//
//  OCClassSettings+Metadata.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.10.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCClassSettings+Metadata.h"
#import "NSString+OCClassSettings.h"
#import "OCMacros.h"
#import "OCLogger.h"

@implementation OCClassSettings (Metadata)

- (nullable NSDictionary<OCClassSettingsKey, id> *)defaultsForClass:(Class<OCClassSettingsSupport>)settingsClass
{
	NSMutableDictionary<OCClassSettingsKey, id> *mergedDefaultSettings = nil;
	OCClassSettingsIdentifier settingsIdentifier;

	if ((settingsIdentifier = [settingsClass classSettingsIdentifier]) != nil)
	{
		NSDictionary<OCClassSettingsKey,id> *defaultSettings;

		// Fetch from default settings
		if ((defaultSettings = [settingsClass defaultSettingsForIdentifier:settingsIdentifier]) != nil)
		{
			mergedDefaultSettings = [defaultSettings mutableCopy];
		}

		// Fetch from registered defaults
		@synchronized(self)
		{
			if ((defaultSettings = [_registeredDefaultValuesByKeyByIdentifier objectForKey:settingsIdentifier]) != nil)
			{
				if (mergedDefaultSettings == nil) { mergedDefaultSettings = [NSMutableDictionary new]; }
				[mergedDefaultSettings addEntriesFromDictionary:defaultSettings];
			}
		}
	}

	return (mergedDefaultSettings);
}

- (nullable NSSet<OCClassSettingsKey> *)keysForClass:(Class<OCClassSettingsSupport>)settingsClass
{
	NSMutableSet<OCClassSettingsKey> *keys = nil;
	OCClassSettingsIdentifier settingsIdentifier;

	if (![settingsClass respondsToSelector:@selector(classSettingsIdentifier)])
	{
		OCLogWarning(@"%@ does not implement the classSettingsIdentifier method", NSStringFromClass(settingsClass));
		return(nil);
	}

	if ((settingsIdentifier = [settingsClass classSettingsIdentifier]) != nil)
	{
		NSDictionary<OCClassSettingsKey,id> *defaultSettings;

		// Fetch from default settings
		if ((defaultSettings = [self defaultsForClass:settingsClass]) != nil)
		{
			if (keys == nil) { keys = [NSMutableSet new]; }
			[keys addObjectsFromArray:defaultSettings.allKeys];
		}

		// Fetch from metadata
		if ([settingsClass respondsToSelector:@selector(classSettingsMetadata)])
		{
			OCClassSettingsMetadataCollection metadataCollection;

			if ((metadataCollection = [settingsClass classSettingsMetadata]) != nil)
			{
				NSArray<OCClassSettingsKey> *metadataKeys;

				if ((metadataKeys = metadataCollection.allKeys) != nil)
				{
					if (keys == nil) { keys = [NSMutableSet new]; }
					[keys addObjectsFromArray:metadataKeys];
				}
			}
		}
	}

	return (keys);
}

- (nullable OCClassSettingsMetadata)metadataForClass:(Class<OCClassSettingsSupport>)settingsClass key:(OCClassSettingsKey)key options:(nullable NSDictionary<OCClassSettingsMetadataOption, id> *)options
{
	OCClassSettingsMetadata metadata = nil;
	OCClassSettingsIdentifier settingsIdentifier = [settingsClass classSettingsIdentifier];
	NSMutableDictionary<OCClassSettingsMetadataKey,id>* mutableMetadata = nil;
	NSArray<NSURL *> *extDocFolderURLs = nil;

	if ([settingsClass respondsToSelector:@selector(classSettingsMetadataForKey:)])
	{
		metadata = [settingsClass classSettingsMetadataForKey:key];
	}

	if (metadata == nil)
	{
		if ([settingsClass respondsToSelector:@selector(classSettingsMetadata)])
		{
			metadata = [[settingsClass classSettingsMetadata] objectForKey:key];
		}
	}

	if (metadata == nil)
	{
		@synchronized(self)
		{
			NSMutableArray<OCClassSettingsMetadataCollection> *metadataCollections;

			if ((metadataCollections = _registeredMetaDataCollectionsByIdentifier[settingsIdentifier]) != nil)
			{
				for (OCClassSettingsMetadataCollection metadataCollection in metadataCollections)
				{
					if ((metadata = metadataCollection[key]) != nil)
					{
						break;
					}
				}
			}
		}
	}

	if ((metadata != nil) && (OCTypedCast(options[OCClassSettingsMetadataOptionAddDefaultValue], NSNumber).boolValue))
	{
		if (mutableMetadata == nil) { mutableMetadata = [metadata mutableCopy]; }

		NSDictionary<OCClassSettingsKey, id> *defaults;

		if ((defaults = [self defaultsForClass:settingsClass]) != nil)
		{
			id defaultValue;

			if ((defaultValue = defaults[key]) != nil)
			{
				mutableMetadata[OCClassSettingsMetadataKeyDocDefaultValue] = defaultValue;
			}
		}
	}

	if ((metadata != nil) && (OCTypedCast(options[OCClassSettingsMetadataOptionFillMissingValues], NSNumber).boolValue))
	{
		if (mutableMetadata == nil) { mutableMetadata = [metadata mutableCopy]; }

		if (mutableMetadata[OCClassSettingsMetadataKeyAutoExpansion] == nil) { mutableMetadata[OCClassSettingsMetadataKeyAutoExpansion] = OCClassSettingsAutoExpansionNone; }
		if (mutableMetadata[OCClassSettingsMetadataKeyStatus] == nil) { mutableMetadata[OCClassSettingsMetadataKeyStatus] = OCClassSettingsKeyStatusAvailable; }
		if (mutableMetadata[OCClassSettingsMetadataKeyKey] == nil) { mutableMetadata[OCClassSettingsMetadataKeyKey] = key; }
		if (mutableMetadata[OCClassSettingsMetadataKeyFlatIdentifier] == nil) { mutableMetadata[OCClassSettingsMetadataKeyFlatIdentifier] = [NSString flatIdentifierFromIdentifier:settingsIdentifier key:key]; }
		if (mutableMetadata[OCClassSettingsMetadataKeyIdentifier] == nil) { mutableMetadata[OCClassSettingsMetadataKeyIdentifier] = settingsIdentifier; }
		if (mutableMetadata[OCClassSettingsMetadataKeyClassName] == nil) { mutableMetadata[OCClassSettingsMetadataKeyClassName] = NSStringFromClass(settingsClass); }
	}

	if ((metadata != nil) && ((extDocFolderURLs = OCTypedCast(options[OCClassSettingsMetadataOptionExternalDocumentationFolders], NSArray)) != nil))
	{
		if (mutableMetadata == nil) { mutableMetadata = [metadata mutableCopy]; }

		OCClassSettingsFlatIdentifier flatIdentifier = [NSString flatIdentifierFromIdentifier:settingsIdentifier key:key];

		for (NSURL *extDocFolderURL in extDocFolderURLs)
		{
			NSURL *docURL = [extDocFolderURL URLByAppendingPathComponent:[flatIdentifier stringByAppendingString:@".md"]];

			if ([NSFileManager.defaultManager fileExistsAtPath:docURL.path])
			{
				NSData *markdownData;

				if ((markdownData = [NSData dataWithContentsOfURL:docURL]) != nil)
				{
					NSString *markdownDescription;

					if ((markdownDescription = [[NSString alloc] initWithData:markdownData encoding:NSUTF8StringEncoding]) != nil)
					{
						if (mutableMetadata[OCClassSettingsMetadataKeyDescription] == nil)
						{
							mutableMetadata[OCClassSettingsMetadataKeyDescription] = markdownDescription;
						}
						else
						{
							mutableMetadata[OCClassSettingsMetadataKeyDescription] = [mutableMetadata[OCClassSettingsMetadataKeyDescription] stringByAppendingFormat:@"\n\n%@", markdownDescription];
						}
					}
				}
			}
		}
	}

	if (mutableMetadata != nil)
	{
		metadata = mutableMetadata;
	}

	return (metadata);
}

@end

OCClassSettingsMetadataKey OCClassSettingsMetadataKeyType = @"type";
OCClassSettingsMetadataKey OCClassSettingsMetadataKeyKey = @"key";
OCClassSettingsMetadataKey OCClassSettingsMetadataKeyIdentifier = @"classIdentifier";
OCClassSettingsMetadataKey OCClassSettingsMetadataKeyFlatIdentifier = @"flatIdentifier";
OCClassSettingsMetadataKey OCClassSettingsMetadataKeyClassName = @"className";
OCClassSettingsMetadataKey OCClassSettingsMetadataKeyDescription = @"description";
OCClassSettingsMetadataKey OCClassSettingsMetadataKeyCategory = @"category";
OCClassSettingsMetadataKey OCClassSettingsMetadataKeyPossibleValues = @"possibleValues";
OCClassSettingsMetadataKey OCClassSettingsMetadataKeyAutoExpansion = @"autoExpansion";
OCClassSettingsMetadataKey OCClassSettingsMetadataKeyValue = @"value";
OCClassSettingsMetadataKey OCClassSettingsMetadataKeyDocDefaultValue = @"defaultValue";
OCClassSettingsMetadataKey OCClassSettingsMetadataKeyFlags = @"flags";
OCClassSettingsMetadataKey OCClassSettingsMetadataKeyCustomValidationClass = @"customValidationClass";
OCClassSettingsMetadataKey OCClassSettingsMetadataKeyStatus = @"status";

OCClassSettingsMetadataType OCClassSettingsMetadataTypeBoolean = @"bool";
OCClassSettingsMetadataType OCClassSettingsMetadataTypeInteger = @"int";
OCClassSettingsMetadataType OCClassSettingsMetadataTypeFloat = @"float";
OCClassSettingsMetadataType OCClassSettingsMetadataTypeDate = @"date";
OCClassSettingsMetadataType OCClassSettingsMetadataTypeString = @"string";
OCClassSettingsMetadataType OCClassSettingsMetadataTypeStringArray = @"stringArray";
OCClassSettingsMetadataType OCClassSettingsMetadataTypeNumberArray = @"numberArray";
OCClassSettingsMetadataType OCClassSettingsMetadataTypeArray = @"array";
OCClassSettingsMetadataType OCClassSettingsMetadataTypeDictionary = @"dictionary";

OCClassSettingsKeyStatus OCClassSettingsKeyStatusRecommended = @"recommended";
OCClassSettingsKeyStatus OCClassSettingsKeyStatusAvailable = @"available";
OCClassSettingsKeyStatus OCClassSettingsKeyStatusAdvanced = @"advanced";
OCClassSettingsKeyStatus OCClassSettingsKeyStatusDebugOnly = @"debugOnly";

OCClassSettingsAutoExpansion OCClassSettingsAutoExpansionNone = @"none";
OCClassSettingsAutoExpansion OCClassSettingsAutoExpansionTrailing = @"trailing";

OCClassSettingsMetadataOption OCClassSettingsMetadataOptionFillMissingValues = @"fillMissing";
OCClassSettingsMetadataOption OCClassSettingsMetadataOptionAddDefaultValue = @"addDefault";
OCClassSettingsMetadataOption OCClassSettingsMetadataOptionExternalDocumentationFolders = @"docFolders";
