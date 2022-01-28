//
//  OCCodeGenerator.m
//  ocapigen
//
//  Created by Felix Schwarz on 26.01.22.
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

#import "OCCodeGenerator.h"
#import "OCCodeFileSegment.h"

@implementation OCCodeGenerator

- (instancetype)initWithTargetFolder:(NSURL *)targetFolderURL
{
	if ((self = [super init]) != nil)
	{
		_targetFolderURL = targetFolderURL;
		_schemaByPath = [NSMutableDictionary new];
		_files = [NSMutableArray new];

		_segmentHeadLeadIn = @"// occgen:";
		// _segmentHeadLeadOut = @"*/";
	}

	return (self);
}

- (void)addSchema:(OCSchema *)schema
{
	_schemaByPath[schema.yamlPath] = schema;
}

#pragma mark - Type and Naming convention / conversion
- (NSDictionary<OCCodeRawType,OCCodeRawType> *)rawToRawTypeMap
{
	if (self.nativeTypesUseCamelCase)
	{
		return (@{
			@"itemreference" 	: @"ItemReference",
			@"identityset" 		: @"IdentitySet",
			@"specialfolder" 	: @"SpecialFolder",
			@"filesysteminfo" 	: @"FilesystemInfo",
			@"directoryobject" 	: @"DirectoryObject",
			@"folderView" 		: @"FolderView",
			@"opengraphfile" 	: @"OpenGraphFile",
			@"Odataerror"		: @"ODataError",
			@"Odataerrormain"	: @"ODataErrorMain",
			@"Odataerrordetail"	: @"ODataErrorDetail"
		});
	}

	return (@{ });
}

- (NSDictionary<OCCodeRawPropertyName,OCCodeNativePropertyName> *)rawToNativePropertyNameMap
{
	return (@{ });
}

- (NSDictionary<OCCodeRawType,OCCodeNativeType> *)rawToNativeTypeMap
{
	return (@{ });
}

- (nullable OCCodeNativeType)collectionTypeFor:(OCCodeNativeType)collectionType itemType:(OCCodeNativeType)itemType asReference:(BOOL)asReference inSegment:(nullable OCCodeFileSegment *)fileSegment
{
	return ([NSString stringWithFormat:@"%@<%@ *>%@", collectionType, itemType, (asReference ? @" *" : @"")]);
}

- (OCCodeNativePropertyName)nativeNameForProperty:(OCSchemaProperty *)property inSegment:(nullable OCCodeFileSegment *)fileSegment
{
	if (property.name != nil)
	{
		OCCodeNativePropertyName nativePropertyName;

		if ((nativePropertyName = self.rawToNativePropertyNameMap[property.name]) != nil)
		{
			return (nativePropertyName);
		}
	}

	return (property.name);
}

- (OCCodeNativeType)nativeTypeForRAWType:(OCCodeRawType)rawType rawFormat:(OCCodeRawFormat)rawFormat rawItemType:(OCCodeRawType)rawItemType asReference:(BOOL)asReference inSegment:(nullable OCCodeFileSegment *)fileSegment
{
	OCCodeNativeType nativeType = nil;
	BOOL dontAddPrefix = NO;

	if (rawType == nil)
	{
		return(nil);
	}

	if ((nativeType == nil) && (rawItemType != nil))
	{
		nativeType = [self collectionTypeFor:[self nativeTypeForRAWType:rawType rawFormat:nil rawItemType:nil asReference:NO inSegment:fileSegment]
					itemType:[self nativeTypeForRAWType:rawItemType rawFormat:nil rawItemType:nil asReference:NO inSegment:fileSegment]
					asReference:asReference
					inSegment:fileSegment];

		dontAddPrefix = YES;
	}

	if (nativeType == nil)
	{
		OCSchema *schema = nil;

		schema = self.schemaByPath[rawType];

		if (schema.name != nil)
		{
			rawType = [self rawTypeForSchemaName:schema.name];
		}
	}

	if (self.rawToRawTypeMap[rawType] != nil)
	{
		rawType = self.rawToRawTypeMap[rawType];
	}

	if (nativeType == nil)
	{
		if (rawFormat != nil)
		{
			if ((nativeType = self.rawToNativeTypeMap[[rawType stringByAppendingFormat:@":%@", rawFormat]]) != nil)
			{
				return (nativeType);
			}
		}

		if (nativeType == nil)
		{
			if ((nativeType = self.rawToNativeTypeMap[rawType]) != nil)
			{
				return (nativeType);
			}
		}
	}

	if (nativeType == nil)
	{
		nativeType = rawType;
	}

	if (self.nativeTypesUseCamelCase)
	{
		nativeType = [[[nativeType substringToIndex:1] uppercaseString] stringByAppendingString:[nativeType substringFromIndex:1]];
	}

	if ((self.nativeTypesPrefix != nil) && !dontAddPrefix)
	{
		nativeType = [self.nativeTypesPrefix stringByAppendingString:nativeType];
	}

	return (nativeType);
}

- (OCCodeNativeType)nativeTypeForProperty:(OCSchemaProperty *)property asReference:(BOOL)asReference remappedFrom:(OCCodeNativeType _Nullable * _Nullable)outRemappedFrom inSegment:(nullable OCCodeFileSegment *)fileSegment
{
	OCCodeNativeType nativeType = nil;
	NSDictionary<OCCodeNativePropertyName, OCCodeNativeType> *nativeTypesByPropertyName;
	BOOL isRemapped = NO;

	if ((nativeTypesByPropertyName = fileSegment.attributes[OCCodeFileSegmentAttributeCustomPropertyTypes]) != nil)
	{
		OCCodeNativePropertyName nativePropertyName;

		if ((nativePropertyName = [self nativeNameForProperty:property inSegment:fileSegment]) != nil)
		{
			if ((nativeType = nativeTypesByPropertyName[nativePropertyName]) != nil)
			{
				isRemapped = YES;
			}
		}
	}

	if ((nativeType == nil) || isRemapped)
	{
		OCCodeNativeType pureNativeType = nil;

		pureNativeType = [self nativeTypeForRAWType:property.type rawFormat:property.format rawItemType:property.itemType asReference:asReference inSegment:fileSegment];

		if (nativeType == nil)
		{
			nativeType = pureNativeType;
		}
		else if (outRemappedFrom != NULL)
		{
			*outRemappedFrom = pureNativeType;
		}
	}

	return (nativeType);
}

- (OCCodeNativeType)rawTypeForSchemaName:(NSString *)schemaName
{
	schemaName = [schemaName stringByReplacingOccurrencesOfString:@"." withString:@""];
	schemaName = [[[schemaName substringToIndex:1] uppercaseString] stringByAppendingString:[schemaName substringFromIndex:1]];

	return (schemaName);
}

- (OCCodeNativeType)nativeTypeNameForSchema:(OCSchema *)schema inSegment:(nullable OCCodeFileSegment *)fileSegment
{
	return ([self nativeTypeForRAWType:[self rawTypeForSchemaName:schema.name] rawFormat:nil rawItemType:nil asReference:NO inSegment:fileSegment]);
}

- (BOOL)isGeneratedType:(OCCodeNativeType)type inSegment:(nullable OCCodeFileSegment *)fileSegment
{
	for (OCSchema *schema in _schemaByPath.allValues)
	{
		if ([[self nativeTypeNameForSchema:schema inSegment:fileSegment] isEqual:type])
		{
			return (YES);
		}
	}

	return (NO);
}

- (OCCodeFile *)fileForName:(NSString *)name
{
	OCCodeFile *file = [[OCCodeFile alloc] initWithURL:[_targetFolderURL URLByAppendingPathComponent:name] generator:self];

	[_files addObject:file];

	return (file);
}

- (void)generate
{
	// Generate content
	for (OCSchema *schema in _schemaByPath.allValues)
	{
		[self generateForSchema:schema];
	}

	// Write files
	for (OCCodeFile *file in _files)
	{
		[file write];
	}
}

- (void)generateForSchema:(OCSchema *)schema
{
	// Subclass
}

#pragma mark - Encode / Decode segment attribute line
- (nullable NSDictionary<OCCodeFileSegmentAttribute, id> *)decodeSegmentAttributesLine:(NSString *)line
{
	if (![line hasPrefix:self.segmentHeadLeadIn])
	{
		return (nil);
	}

	if ((self.segmentHeadLeadOut != nil) && ![line hasSuffix:self.segmentHeadLeadOut])
	{
		return (nil);
	}

	NSString *lineContent = [line substringWithRange:NSMakeRange(self.segmentHeadLeadIn.length, line.length - self.segmentHeadLeadIn.length - self.segmentHeadLeadOut.length)];

	NSRange dividerRange = [lineContent rangeOfString:@"{"]; // Find start of JSON

	if (dividerRange.location == NSNotFound)
	{
		// Just the name - trim white space
		return (@{
			OCCodeFileSegmentAttributeName : [lineContent stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]
		});
	}
	else
	{
		// Name + JSON
		NSString *name = [[lineContent substringToIndex:dividerRange.location] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
		NSString *jsonString = [[lineContent substringFromIndex:dividerRange.location] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
		NSMutableDictionary<OCCodeFileSegmentAttribute, id> *attributesDict = [NSMutableDictionary new];

		if (name.length != 0)
		{
			attributesDict[OCCodeFileSegmentAttributeName] = name;
		}

		if (jsonString.length != 0)
		{
			NSError *error = nil;
			id jsonObject = [NSJSONSerialization JSONObjectWithData:[jsonString dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&error];

			if ((jsonObject == nil) && (error != nil))
			{
				NSLog(@"Error parsing %@: %@", lineContent, error);
			}
			else
			{
				if ([jsonObject isKindOfClass:NSDictionary.class])
				{
					[attributesDict addEntriesFromDictionary:(NSDictionary *)jsonObject];
				}
			}
		}

		return (attributesDict);
	}

	return (nil);
}

- (NSString *)encodeSegmentAttributesLineFrom:(OCCodeFileSegment *)segment
{
	NSMutableDictionary<OCCodeFileSegmentAttribute, id> *attributesDict = [NSMutableDictionary new];
	NSError *error = nil;

	if (segment.attributes != nil)
	{
		[attributesDict addEntriesFromDictionary:segment.attributes];
		attributesDict[OCCodeFileSegmentAttributeName] = nil;
	}

	return ([NSString stringWithFormat:@"%@ %@%@%@%@",
			self.segmentHeadLeadIn,
			segment.name,
			((attributesDict.count > 0) ? @" " : @""),
			((attributesDict.count > 0) ? [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:attributesDict options:NSJSONWritingSortedKeys error:&error] encoding:NSUTF8StringEncoding] : @""),
			((self.segmentHeadLeadOut != nil) ? self.segmentHeadLeadOut : @"")
		]);
}

@end
