//
//  OCXMLParserNode.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCXMLParserNode.h"


@implementation OCXMLParserNode

@synthesize attributes;
@synthesize name;
@synthesize keyValues = _keyValues;
@synthesize children = _children;

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
		if (_children == nil)
		{
			_children = [NSMutableArray new];
		}
		
		[_children addObject:child];
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
						foundNodes = [NSMutableArray arrayWithObject:xmlNode];
					}
					else
					{
						[foundNodes addObject:xmlNode];
					}
				}
				else
				{
					NSArray *childFoundNodes;
					
					if ((childFoundNodes = [xmlNode _nodesForXPathArray:xPathArray index:(index+1)]) != nil)
					{
						if (foundNodes == nil)
						{
							foundNodes = [NSMutableArray arrayWithArray:childFoundNodes];
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

- (NSString *)description
{
	NSMutableString *childrenString = [NSMutableString string];
	
	for (OCXMLParserNode *parserNode in _children)
	{
		[childrenString appendFormat:@"%@, ", [parserNode description]];
	}

	return ([NSString stringWithFormat:@"<%@ attributes: %@ keyValues: %@ children: %@>", self.name, self.attributes, self.keyValues, childrenString]);
}
@end
