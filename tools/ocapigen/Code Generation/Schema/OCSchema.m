//
//  OCSchema.m
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

#import "OCSchema.h"
#import "OCSchemaProperty.h"
#import "OCYAMLNode+GeneratorTools.h"
#import "NSString+GeneratorTools.h"

@implementation OCSchema

- (instancetype)initWithYAMLNode:(OCYAMLNode *)node parser:(OCYAMLParser *)parser
{
	if ((self = [super init]) != nil)
	{
		self.schemaNode = node;

		self.name = node.name;
		self.desc = node.childrenByName[@"description"].value;

		self.yamlPath = node.path;

		self.properties = [NSMutableArray new];

		[self addPropertiesFrom:node additionalRequired:nil];

		if (node.childrenByName[@"allOf"]) {
			for (NSString *reference in OCTypedCast(node.childrenByName[@"allOf"].value, NSArray)) {
				OCYAMLNode *referencedNode;
				if ((referencedNode = [parser nodeForReference:reference]) != nil)
				{
					[self addPropertiesFrom:referencedNode additionalRequired:node.requiredProperties];
				}
			}
		}

		if (node.childrenByName[@"enum"] != nil)
		{
			self.enumValues = [node.childrenByName[@"enum"].value valuesFromArrayString];
		}
	}

	return (self);
}

- (void)addPropertiesFrom:(OCYAMLNode *)node additionalRequired:(NSArray<NSString *> *)additionalRequired
{
	if (self.type == nil)
	{
		self.type = node.childrenByName[@"type"].value;
	}

	for (OCYAMLNode *propertyNode in node.childrenByName[@"properties"].children)
	{
		OCSchemaProperty *property = [OCSchemaProperty new];

		property.schema = self;
		property.yamlNode= propertyNode;

		property.name = propertyNode.name;
		property.desc = propertyNode.childrenByName[@"description"].value;
		property.type = propertyNode.childrenByName[@"type"].value;
		property.required = [node.requiredProperties containsObject:propertyNode.name] || [additionalRequired containsObject:propertyNode.name];
		property.format = propertyNode.childrenByName[@"format"].value;
		property.pattern = propertyNode.childrenByName[@"pattern"].value;

		if (property.type == nil)
		{
			property.type = propertyNode.childrenByName[@"$ref"].value;
		}

		if ([property.type isEqual:@"array"] && (propertyNode.childrenByName[@"items"] != nil))
		{
			OCSchemaPropertyType itemType = propertyNode.childrenByName[@"items"].childrenByName[@"$ref"].value;

			if (itemType == nil)
			{
				itemType = propertyNode.childrenByName[@"items"].childrenByName[@"type"].value;
			}

			property.itemType = itemType;
		}

		[self.properties addObject:property];
	}
}

@end

OCSchemaType OCSchemaTypeObject = @"object";
OCSchemaType OCSchemaTypeString = @"string";
