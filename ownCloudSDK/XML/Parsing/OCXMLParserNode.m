//
//  OCXMLParserNode.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.03.18.
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


#import "OCXMLParserNode.h"

@implementation OCXMLParserNode

@synthesize attributes;
@synthesize name;
@synthesize keyValues = _keyValues;
@synthesize children = _children;

@synthesize retainChildren = _retainChildren;

- (instancetype)initWithXMLParser:(OCXMLParser *)xmlParser elementName:(NSString *)elementName namespaceURI:(NSString *)namespaceURI attributes:(NSDictionary<NSString *,NSString *> *)attributes error:(NSError *__autoreleasing *)outError
{
	if ((self = [self init]) != nil)
	{
		self.name = elementName;
		self.attributes = attributes;
	}
	
	return (self);
}

- (NSError *)xmlParser:(OCXMLParser *)xmlParser parseKey:(NSString *)key value:(id)value attributes:(NSDictionary <NSString*,NSString*> *)attributes
{
	if (_keyValues==nil)
	{
		_keyValues = [NSMutableDictionary new];
	}
	
	_keyValues[key] = ((value==nil) ? [NSNull null] : value);

	return (nil);
}

- (NSError *)xmlParser:(OCXMLParser *)xmlParser completedParsingForChild:(OCXMLParserNode *)child
{
	if (child != nil)
	{
		if (_retainChildren)
		{
			if (_children == nil)
			{
				_children = [NSMutableArray new];
			}

			[_children addObject:child];
		}
	}
	
	return (nil);
}

- (NSArray <OCXMLParserNode *> *)_nodesForXPathArray:(NSArray <NSString *> *)xPathArray index:(NSUInteger)index
{
	NSMutableArray <OCXMLParserNode *> *foundNodes = nil;
	BOOL isTarget = NO;
	NSUInteger xPathArrayCount = xPathArray.count;
	
	if (xPathArrayCount > index)
	{
		NSString *localPath = xPathArray[index];
		
		isTarget = ((xPathArrayCount-1) == index);
		
		for (OCXMLParserNode *xmlNode in _children)
		{
			if ([xmlNode.name isEqualToString:localPath])
			{
				if (isTarget)
				{
					if (foundNodes == nil)
					{
						foundNodes = [NSMutableArray new];
					}

					[foundNodes addObject:xmlNode];
				}
				else
				{
					NSArray *childFoundNodes;
					
					if ((childFoundNodes = [xmlNode _nodesForXPathArray:xPathArray index:(index+1)]) != nil)
					{
						if (foundNodes == nil)
						{
							foundNodes = [[NSMutableArray alloc] initWithArray:childFoundNodes];
						}
						else
						{
							[foundNodes addObjectsFromArray:childFoundNodes];
						}
					}
				}
			}
		}
	}
	
	return (foundNodes);
}

- (NSArray <OCXMLParserNode *> *)nodesForXPath:(NSString *)xPath
{
	if (xPath != nil)
	{
		return ([self _nodesForXPathArray:[xPath componentsSeparatedByString:@"/"] index:0]);
	}
	
	return (nil);
}

- (void)enumerateChildNodesWithName:(NSString *)name usingBlock:(void(^)(OCXMLParserNode *childNode))block
{
	if (block==nil) { return; }

	for (OCXMLParserNode *childNode in _children)
	{
		if ([childNode.name isEqualToString:name])
		{
			@autoreleasepool {
				block(childNode);
			}
		}
	}
}

- (void)enumerateChildNodesForTarget:(id)target withBlockForElementNames:(OCXMLParserNodeChildNodesEnumeratorDictionary)blockForElementNamesDict;
{
	for (OCXMLParserNode *childNode in _children)
	{
		if (childNode->name != nil)
		{
			void(^parseBlock)(id target, OCXMLParserNode *childNode);

			if ((parseBlock = blockForElementNamesDict[childNode->name]) != nil)
			{
				@autoreleasepool {
					parseBlock(target, childNode);
				}
			}
		}
	}
}

- (void)enumerateKeyValuesForTarget:(id)target withBlockForKeys:(OCXMLParserNodeKeyValueEnumeratorDictionary)blockForKeysDict
{
	[_keyValues enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, id _Nonnull value, BOOL * _Nonnull stop) {
		void(^parseBlock)(id target, NSString *key, id value);

		if ((parseBlock = blockForKeysDict[key]) != nil)
		{
			@autoreleasepool {
				parseBlock(target, key, value);
			}
		}
	}];
}

- (NSString *)description
{
	NSMutableString *childrenString = [NSMutableString new];
	
	for (OCXMLParserNode *parserNode in _children)
	{
		[childrenString appendFormat:@"%@, ", [parserNode description]];
	}

	return ([NSString stringWithFormat:@"<%@ attributes: %@ keyValues: %@ children: %@>", self.name, self.attributes, self.keyValues, childrenString]);
}
@end
