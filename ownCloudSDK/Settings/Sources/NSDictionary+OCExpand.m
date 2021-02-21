//
//  NSDictionary+OCExpand.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.02.21.
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

/*
	Parsing a special key-value syntax:
		$	everything past "$" is a key path
		.	delimiter for key path components
		[x]	if a path component ends with a ], it identifies an array and x is the position in that array.

	Example:
	{
		"test$[0].index" 		: 0,
		"test$[0].name"  		: "hello",
		"test$[0].attributes.highlight" : true,
		"test$[0].nicknames[0]" 	: "hi",
		"test$[0].nicknames[1]" 	: "howdy",
	}

	represents:
		{
			"test" : [
				{
					"index" : 0,
					"name" : "hello"
					"attributes" : {
						"highlight" : true
					},
					"nicknames" : [
						"hi",
						"howdy"
					]
				}
			]
 		}

*/

#import "NSDictionary+OCExpand.h"
#import "OCLogger.h"

@implementation NSDictionary (OCExpand)

- (NSDictionary *)expandedDictionary
{
	NSMutableDictionary<NSString *, id> *resultDict = [NSMutableDictionary new];
	NSMutableDictionary<NSString *, id> *sourceDict = [NSMutableDictionary new];

	// Break out key[idx] into "key.[idx]" to normalize the keys for sorting
	for (NSString *key in self.allKeys)
	{
		NSRange escapeRange = [key rangeOfString:@"$"];

		if (escapeRange.location != NSNotFound)
		{
			NSArray<NSString *> *rawPathComponents;
			NSMutableArray<NSString *> *pathComponents = [NSMutableArray new];
			NSString *effectiveKey = nil;

			rawPathComponents = [[key substringFromIndex:escapeRange.location+1] componentsSeparatedByString:@"."];
			effectiveKey = [key substringToIndex:escapeRange.location];

			// Pre process
			for (NSString *pathComponent in rawPathComponents)
			{
				if ([pathComponent hasSuffix:@"]"])
				{
					NSRange startBracketRange = [pathComponent rangeOfString:@"["];

					if (startBracketRange.location != NSNotFound)
					{
						if (startBracketRange.location == 0)
						{
							[pathComponents addObject:pathComponent];
						}
						else
						{
							[pathComponents addObject:[pathComponent substringToIndex:startBracketRange.location]];
							[pathComponents addObject:[pathComponent substringFromIndex:startBracketRange.location]];
						}
					}
				}
				else
				{
					[pathComponents addObject:pathComponent];
				}
			}

			sourceDict[[effectiveKey stringByAppendingFormat:@"$%@", [pathComponents componentsJoinedByString:@"."]]] = [self valueForKey:key];
		}
		else
		{
			sourceDict[key] = [self valueForKey:key];
		}
	}

	// Sort keys, so that f.ex. [0] comes before [1], so we don't have values falling into "holes"
	NSArray<NSString *> *keys = nil;

	keys = [sourceDict.allKeys sortedArrayUsingSelector:@selector(compare:)];

	for (NSString *key in keys)
	{
		NSRange escapeRange = [key rangeOfString:@"$"];
		NSString *effectiveKey = key;
		id value = [sourceDict valueForKey:key];

		if (escapeRange.location != NSNotFound)
		{
			NSArray<NSString *> *pathComponents = [[key substringFromIndex:escapeRange.location+1] componentsSeparatedByString:@"."];

			effectiveKey = [key substringToIndex:escapeRange.location];

			// Navigate hierarchy
			id targetCollection = resultDict;
			id targetCollectionLocation = effectiveKey;

			// Build intermediate collection graph
			for (NSString *pathComponent in pathComponents)
			{
				id collection = nil;
				id collectionLocation = nil;

				// Retrieve existing collection object
				if ([targetCollection isKindOfClass:NSDictionary.class] && [targetCollectionLocation isKindOfClass:NSString.class])
				{
					collection = [targetCollection objectForKey:targetCollectionLocation];
				}
				else if ([targetCollection isKindOfClass:NSArray.class] && [targetCollectionLocation isKindOfClass:NSNumber.class])
				{
					if (((NSArray *)targetCollection).count > ((NSNumber *)targetCollectionLocation).integerValue)
					{
						collection = [targetCollection objectAtIndex:((NSNumber *)targetCollectionLocation).unsignedIntegerValue];
					}
				}

				// Parse path component
				if ([pathComponent hasSuffix:@"]"])
				{
					// Array
					if (collection == nil)
					{
						collection = [NSMutableArray new];
					}

					collectionLocation = @([[pathComponent substringWithRange:NSMakeRange(1, pathComponent.length-2)] integerValue]);
				}
				else
				{
					// Dictionary
					if (collection == nil)
					{
						collection = [NSMutableDictionary new];
					}

					collectionLocation = pathComponent;
				}

				if ([targetCollection isKindOfClass:NSDictionary.class] && [targetCollectionLocation isKindOfClass:NSString.class])
				{
					// Insert into dictionary
					[targetCollection setObject:collection forKey:targetCollectionLocation];
				}
				else if ([targetCollection isKindOfClass:NSArray.class] && [targetCollectionLocation isKindOfClass:NSNumber.class])
				{
					// Insert into array
					if (((NSArray *)targetCollection).count <= ((NSNumber *)targetCollectionLocation).integerValue)
					{
						// Collection has no object yet at index targetCollectionLocation, so append it
						[(NSMutableArray *)targetCollection addObject:collection];
					}
				}
				else
				{
					OCLogWarning(@"Conflicting collection type for path component %@ in %@", pathComponent, key);
				}

				targetCollection = collection;
				targetCollectionLocation = collectionLocation;
			}

			// Set value
			if ([targetCollection isKindOfClass:NSDictionary.class] && [targetCollectionLocation isKindOfClass:NSString.class])
			{
				// Insert into dictionary
				[targetCollection setObject:value forKey:targetCollectionLocation];
			}
			else if ([targetCollection isKindOfClass:NSArray.class] && [targetCollectionLocation isKindOfClass:NSNumber.class])
			{
				// Insert into array
				if (((NSArray *)targetCollection).count <= ((NSNumber *)targetCollectionLocation).integerValue)
				{
					// Collection has no object yet at index targetCollectionLocation, so append it
					[(NSMutableArray *)targetCollection addObject:value];
				}
			}
			else
			{
				OCLogWarning(@"Conflicting collection type for path component %@ in %@", targetCollectionLocation, key);
			}
		}
		else
		{
			resultDict[key] = value;
		}
	}

	return (resultDict);
}

@end
