//
//  OCXMLParserElement.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCXMLParserElement.h"

@implementation OCXMLParserElement

@synthesize attributes;
@synthesize elementName;
@synthesize keyValues = _keyValues;
@synthesize children = _children;

- (instancetype)initWithXMLParser:(OCXMLParser *)xmlParser elementName:(NSString *)elementName attributes:(NSDictionary <NSString*,NSString*> *)attributes error:(NSError **)outError
{
	if ((self = [self init]) != nil)
	{
		self.elementName = elementName;
		self.attributes = attributes;
	}
	
	return (self);
}

- (NSError *)xmlParser:(OCXMLParser *)xmlParser parseKey:(NSString *)key value:(NSString *)value attributes:(NSDictionary <NSString*,NSString*> *)attributes
{
	if (_keyValues==nil)
	{
		_keyValues = [NSMutableDictionary new];
	}
	
	_keyValues[key] = value;

	return (nil);
}

- (NSError *)xmlParser:(OCXMLParser *)xmlParser completedParsingForChild:(OCXMLElementParser)child
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

- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@ attributes: %@ keyValues: %@ children: %@>", self.elementName, self.attributes, self.keyValues, self.children]);
}

@end
