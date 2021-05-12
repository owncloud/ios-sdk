//
//  OCClassSettings+Documentation.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 30.10.20.
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

#import "OCClassSettings+Documentation.h"
#import "NSArray+ObjCRuntime.h"
#import "OCLogger.h"

@implementation OCClassSettings (Documentation)

- (NSArray<Class<OCClassSettingsSupport>> *)implementingClasses
{
	return ([NSArray classesImplementing:@protocol(OCClassSettingsSupport)]);
}

- (id)_makeJSONSafe:(id)object
{
    	if (	[object isKindOfClass:NSString.class] ||
		[object isKindOfClass:NSNumber.class] ||
		[object isKindOfClass:NSArray.class] ||
		[object isKindOfClass:NSNull.class])
	{
		return (object);
	}

	if ([object isKindOfClass:[NSDictionary class]])
	{
		NSMutableDictionary *newDict = [NSMutableDictionary new];

		for (id inKey in ((NSDictionary *)object))
		{
			id key = inKey;

			if (![key isKindOfClass:NSString.class])
			{
				if ([key respondsToSelector:@selector(stringValue)])
				{
					key = [key stringValue];
				}
				else
				{
					OCLogWarning(@"Can't convert key %@ (%@) to string", key, NSStringFromClass([key class]));
					key = nil;
				}
			}

			if (key != nil)
			{
				id origValue = [(NSDictionary *)object objectForKey:inKey];
				id value;

				if ((value = [self _makeJSONSafe:origValue]) != nil)
				{
					[newDict setObject:value forKey:key];
				}
				else
				{
					OCLogWarning(@"Can't convert key %@ value %@ (%@) to JSON-safe", key, origValue, NSStringFromClass([origValue class]));
				}
			}
		}

		return (newDict);
	}

	return (nil);
}

- (NSArray<NSDictionary<OCClassSettingsMetadataKey, id> *> *)documentationDictionaryWithOptions:(nullable NSDictionary<OCClassSettingsDocumentationOption, id> *)options
{
	NSMutableArray<NSDictionary<OCClassSettingsMetadataKey, id> *> *docDicts = [NSMutableArray new];
	NSArray<Class<OCClassSettingsSupport>> *implementingClasses = [self implementingClasses];
	NSMutableSet<OCClassSettingsFlatIdentifier> *flatIdentifiers = [NSMutableSet new];

	for (Class<OCClassSettingsSupport> implementingClass in implementingClasses)
	{
		NSSet<OCClassSettingsKey> *keys;

		if ((keys = [self keysForClass:implementingClass]) != nil)
		{
			for (OCClassSettingsKey key in keys)
			{
				OCClassSettingsMetadata metaData;

				if ((metaData = [self metadataForClass:implementingClass key:key options:@{
					OCClassSettingsMetadataOptionFillMissingValues : @(YES),
					OCClassSettingsMetadataOptionAddDefaultValue : @(YES),
					OCClassSettingsMetadataOptionSortPossibleValues : @(YES),
					OCClassSettingsMetadataOptionExpandPossibleValues : @(YES),
					OCClassSettingsMetadataOptionAddCategoryTags: @(YES),
					OCClassSettingsMetadataOptionExternalDocumentationFolders : (options[OCClassSettingsDocumentationOptionExternalDocumentationFolders] ? options[OCClassSettingsDocumentationOptionExternalDocumentationFolders] : @[]),
				}]) != nil)
				{
					OCClassSettingsFlatIdentifier flatIdentifier = metaData[OCClassSettingsMetadataKeyFlatIdentifier];

					if ((flatIdentifier != nil) && ![flatIdentifiers containsObject:flatIdentifier])
					{
						if (((NSNumber *)options[OCClassSettingsDocumentationOptionOnlyJSONTypes]).boolValue)
						{
							metaData = [self _makeJSONSafe:metaData];
						}

						[flatIdentifiers addObject:flatIdentifier];

						[docDicts addObject:metaData];
					}
				}
				else
				{
					OCLogWarning(@"No metadata available for %@.%@", NSStringFromClass(implementingClass), key);
				}
			}
		}
	}

	[docDicts sortUsingDescriptors:@[
		[NSSortDescriptor sortDescriptorWithKey:OCClassSettingsMetadataKeySubCategory ascending:YES],
		[NSSortDescriptor sortDescriptorWithKey:OCClassSettingsMetadataKeyFlatIdentifier ascending:YES]
	]];

	return (docDicts);
}

@end

OCClassSettingsDocumentationOption OCClassSettingsDocumentationOptionExternalDocumentationFolders = @"external-documentation-folders";
OCClassSettingsDocumentationOption OCClassSettingsDocumentationOptionOnlyJSONTypes = @"only-json-types";

