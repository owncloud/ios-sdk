//
//  OCXMLNode.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.03.18.
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

#import "OCXMLNode.h"

@implementation OCXMLNode

@synthesize kind = _kind;

@synthesize parent = _parent;
@synthesize children = _children;
@synthesize attributes = _attributes;

@synthesize name = _name;

@synthesize objectValue = _objectValue;
@synthesize stringValue = _stringValue;

+ (instancetype)documentWithRootElement:(OCXMLNode *)rootNode
{
	OCXMLNode *node = [OCXMLNode new];

	node.kind = OCXMLNodeKindDocument;

	node.children = [NSMutableArray arrayWithObject:rootNode];
	
	return (node);
}

+ (instancetype)elementWithName:(NSString *)name
{
	OCXMLNode *node = [OCXMLNode new];

	node.kind = OCXMLNodeKindElement;

	node.name = name;
	
	return (node);
}


+ (instancetype)elementWithName:(NSString *)name stringValue:(NSString *)stringValue
{
	OCXMLNode *node = [OCXMLNode new];

	node.kind = OCXMLNodeKindElement;

	node.name = name;
	node.stringValue = stringValue;
	
	return (node);
}

+ (instancetype)elementWithName:(NSString *)name children:(NSArray <OCXMLNode *> *)children
{
	OCXMLNode *node = [OCXMLNode new];

	node.kind = OCXMLNodeKindElement;

	node.name = name;
	node.children = (children != nil) ? [NSMutableArray arrayWithArray:children] : nil;
	
	return (node);
}

+ (instancetype)elementWithName:(NSString *)name attributes:(NSArray <OCXMLNode *> *)attributes children:(NSArray <OCXMLNode *> *)children
{
	OCXMLNode *node = [OCXMLNode new];

	node.kind = OCXMLNodeKindElement;

	node.name = name;
	node.children = (children != nil) ? [NSMutableArray arrayWithArray:children] : nil;
	node.attributes = (attributes != nil) ? [NSMutableArray arrayWithArray:attributes] : nil;

	return (node);
}

+ (instancetype)elementWithName:(NSString *)name attributes:(NSArray <OCXMLNode *> *)attributes
{
	OCXMLNode *node = [OCXMLNode new];

	node.kind = OCXMLNodeKindElement;

	node.name = name;
	node.attributes = (attributes != nil) ? [NSMutableArray arrayWithArray:attributes] : nil;

	return (node);
}

+ (instancetype)elementWithName:(NSString *)name attributes:(NSArray <OCXMLNode *> *)attributes stringValue:(NSString *)stringValue
{
	OCXMLNode *node = [OCXMLNode new];

	node.kind = OCXMLNodeKindElement;

	node.name = name;
	node.attributes = (attributes != nil) ? [NSMutableArray arrayWithArray:attributes] : nil;
	node.stringValue = stringValue;

	return (node);
}

+ (instancetype)attributeWithName:(NSString *)name stringValue:(NSString *)stringValue
{
	OCXMLNode *node = [OCXMLNode new];

	node.kind = OCXMLNodeKindAttribute;

	node.name = name;
	node.stringValue = stringValue;
	
	return (node);
}

+ (instancetype)namespaceWithName:(NSString *)name stringValue:(NSString *)stringValue
{
	OCXMLNode *node = [OCXMLNode new];

	node.kind = OCXMLNodeKindNamespace;

	node.name = name;
	node.stringValue = stringValue;
	
	return (node);
}

+ (instancetype)commentWithContent:(NSString *)comment
{
	OCXMLNode *node = [OCXMLNode new];

	node.kind = OCXMLNodeKindComment;

	node.stringValue = comment;
	
	return (node);
}

- (void)setChildren:(NSMutableArray<OCXMLNode *> *)children
{
	for (OCXMLNode *child in children)
	{
		child.parent = self;
	}
	
	_children = children;
}

- (void)setAttributes:(NSMutableArray<OCXMLNode *> *)attributes
{
	for (OCXMLNode *attribute in attributes)
	{
		attribute.parent = self;
	}
	
	_attributes = attributes;
}

- (void)addChild:(OCXMLNode *)child
{
	if (child != nil)
	{
		child.parent = self;
		
		if (_children == nil)
		{
			_children = [[NSMutableArray alloc] initWithObjects:child, nil];
		}
		else
		{
			[_children addObject:child];
		}
	}
}

- (void)addChildren:(NSArray <OCXMLNode *> *)children
{
	if (children != nil)
	{
		for (OCXMLNode *child in children)
		{
			child.parent = self;
		}
		
		if (_children == nil)
		{
			_children = [[NSMutableArray alloc] initWithArray:children];
		}
		else
		{
			[_children addObjectsFromArray:children];
		}
	}
}

- (void)removeChild:(OCXMLNode *)child
{
	if (child != nil)
	{
		child.parent = nil;
		
		[_children removeObject:child];
	}
}

- (void)removeFromParent
{
	[self.parent removeChild:self];
}

- (NSArray <OCXMLNode *> *)_nodesForXPathArray:(NSArray <NSString *> *)xPathArray index:(NSUInteger)index
{
	NSMutableArray <OCXMLNode *> *foundNodes = nil;
	BOOL isTarget = NO;
	NSUInteger xPathArrayCount = xPathArray.count;
	
	if (xPathArrayCount > index)
	{
		NSString *localPath = xPathArray[index];
		
		isTarget = ((xPathArrayCount-1) == index);
		
		for (OCXMLNode *xmlNode in _children)
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

- (NSArray <OCXMLNode *> *)nodesForXPath:(NSString *)xPath
{
	if (xPath != nil)
	{
		return ([self _nodesForXPathArray:[xPath componentsSeparatedByString:@"/"] index:0]);
	}
	
	return (nil);
}

- (NSString *)_XMLStringFromNodes:(NSArray <OCXMLNode *> *)nodes
{
	NSMutableString *childrenXMLString = [NSMutableString string];

	for (OCXMLNode *node in nodes)
	{
		NSString *nodeXMLString;
		
		if ((nodeXMLString = [node XMLString]) != nil)
		{
			[childrenXMLString appendString:nodeXMLString];
		}
	}
	
	return (childrenXMLString);
}

- (NSString *)_escapeString:(NSString *)inString
{
	NSString *outString = inString;

	if (inString != nil)
	{
		NSMutableString *escapedString = nil;
		NSUInteger replacements = 0;
	
		escapedString = [NSMutableString stringWithString:inString];
		
		replacements += [escapedString replaceOccurrencesOfString:@"&"  withString:@"&amp;"  options:0 range:NSMakeRange(0, escapedString.length)];
		replacements += [escapedString replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:0 range:NSMakeRange(0, escapedString.length)];
		replacements += [escapedString replaceOccurrencesOfString:@"'"  withString:@"&apos;" options:0 range:NSMakeRange(0, escapedString.length)];
		replacements += [escapedString replaceOccurrencesOfString:@"<"  withString:@"&lt;"   options:0 range:NSMakeRange(0, escapedString.length)];
		replacements += [escapedString replaceOccurrencesOfString:@">"  withString:@"&gt;"   options:0 range:NSMakeRange(0, escapedString.length)];
		
		if (replacements == 0)
		{
			outString = inString;
		}
		else
		{
			outString = escapedString;
		}
	}
	
	return (outString);
}

- (NSString *)XMLString
{
	NSString *xmlString = nil;

	switch(_kind)
	{
		case OCXMLNodeKindDocument:
			// Document node
			xmlString = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n%@", [self _XMLStringFromNodes:self.children]];
		break;

		case OCXMLNodeKindElement:
			if ((_children.count == 0) && (self.stringValue==nil))
			{
				xmlString = [NSString stringWithFormat:@"<%@%@/>\n", self.name, [self _XMLStringFromNodes:self.attributes]];
			}
			else
			{
				if (self.stringValue != nil)
				{
					xmlString = [NSString stringWithFormat:@"<%@%@>%@</%@>\n", self.name, [self _XMLStringFromNodes:self.attributes], [self _escapeString:self.stringValue], self.name];
				}
				else
				{
					xmlString = [NSString stringWithFormat:@"<%@%@>\n%@</%@>\n", self.name, [self _XMLStringFromNodes:self.attributes], [self _XMLStringFromNodes:self.children], self.name];
				}
			}
		break;

		case OCXMLNodeKindAttribute:
			xmlString = [NSString stringWithFormat:@" %@=\"%@\"", self.name,  [self _escapeString:self.stringValue]];
		break;

		case OCXMLNodeKindNamespace:
			if (self.name != nil)
			{
				xmlString = [NSString stringWithFormat:@" xmlns:%@=\"%@\"", self.name, [self _escapeString:self.stringValue]];
			}
			else
			{
				xmlString = [NSString stringWithFormat:@" xmlns=\"%@\"", [self _escapeString:self.stringValue]];
			}
		break;
		
		case OCXMLNodeKindComment:
			xmlString = [NSString stringWithFormat:@"<!-- %@ -->\n", self.stringValue];
		break;
	}
	
	return (xmlString);
}

- (NSData *)XMLUTF8Data
{
	return ([[self XMLString] dataUsingEncoding:NSUTF8StringEncoding]);
}

@end

