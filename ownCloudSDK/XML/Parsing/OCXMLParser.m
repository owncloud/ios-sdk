//
//  OCXMLParser.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCXMLParser.h"
#import "OCLogger.h"
#import "OCXMLParserNode.h"
#import "OCItem.h"

@implementation OCXMLParser

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_valueConverterByElementName = [NSMutableDictionary new];
		_objectCreationClassByElementName = [NSMutableDictionary new];

		_stack = [NSMutableArray new];
		_elementPath = [NSMutableArray new];

		_elementContents = [NSMutableArray new];
		_elementAttributes = [NSMutableArray new];
		_elementContentsEmptyIndexes = [NSMutableIndexSet new];
		_elementContentsLastIndex = -1;

		_elementObjectifiedIndexes = [NSMutableIndexSet new];

		_errors = [NSMutableArray new];
		_parsedObjects = [NSMutableArray new];
	}
	
	return(self);
}

- (instancetype)initWithParser:(NSXMLParser *)xmlParser
{
	if ((self = [self init]) != nil)
	{
		_xmlParser = xmlParser;
		_xmlParser.delegate = self;
	}
	
	return(self);
}

- (void)dealloc
{
	_xmlParser.delegate = nil;
}

#pragma mark - Parse
- (BOOL)parse
{
	return ([_xmlParser parse]);
}

#pragma mark - Parser delegate
- (void)parserDidEndDocument:(NSXMLParser *)parser
{
	if (_stack.count > 0)
	{
		OCLogWarning(@"Stack not empty: ", _stack);
	}
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	[_errors addObject:parseError];
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary<NSString *,NSString *> *)attributeDict
{
	OCXMLParserNode *elementNode = nil;
	NSError *error = nil;
	
	if ((elementNode = [[OCXMLParserNode alloc] initWithXMLParser:self elementName:elementName namespaceURI:namespaceURI attributes:attributeDict error:&error]) != nil)
	{
		[_stack addObject:elementNode];
	}
	else if (error != nil)
	{
		[_errors addObject:error];
	}
	
	[_elementPath addObject:elementName];

	[_elementAttributes addObject:((attributeDict!=nil) ? attributeDict : @{})];
	
	[_elementContents addObject:[NSMutableString string]];
	_elementContentsLastIndex++;
	[_elementContentsEmptyIndexes addIndex:_elementContentsLastIndex];
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	[[_elementContents lastObject] appendString:string];
	[_elementContentsEmptyIndexes removeIndex:_elementContentsLastIndex];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	id elementContents = nil;
	OCXMLParserNode *lastParserElementOnStack = _stack.lastObject;

	if (![_elementContentsEmptyIndexes containsIndex:_elementContentsLastIndex])
	{
		elementContents = [_elementContents lastObject];
	
		if (_stack.count > 1)
		{
			OCXMLParserElementValueConverter valueConverter;
		
			if ((valueConverter = _valueConverterByElementName[_elementPath.lastObject]) != nil)
			{
				id convertedValue = nil;
				NSError *error;
				
				if ((error = valueConverter(elementName, elementContents, namespaceURI, _elementAttributes.lastObject, &convertedValue)) != nil)
				{
					[_errors addObject:error];
				}
				else
				{
					elementContents = convertedValue;
				}
			}
		
			[[_stack objectAtIndex:_stack.count-2] xmlParser:self parseKey:_elementPath.lastObject value:elementContents attributes:_elementAttributes.lastObject];
		}
	}
	else
	{
	
		// Tell parser that its parsing has completed
		[lastParserElementOnStack xmlParser:self completedParsingForChild:nil];
		
		// Tell parent that parsing of this child has completed
		if (_stack.count > 1)
		{
			[_stack[_stack.count-2] xmlParser:self completedParsingForChild:[_stack lastObject]];
		}
		else
		{
			NSLog(@"%@", lastParserElementOnStack);
			NSLog(@"%@", [(OCXMLParserNode *)lastParserElementOnStack nodesForXPath:@"d:response/d:propstat"]);
		}
	}

	[_stack removeLastObject];

	[_elementPath removeLastObject];

	if (_elementContentsLastIndex < -1) { _elementContentsLastIndex = -1; }
	[_elementAttributes removeLastObject];

	[_elementContents removeLastObject];
	[_elementContentsEmptyIndexes removeIndex:_elementContentsLastIndex];
	_elementContentsLastIndex--;
}

@end
