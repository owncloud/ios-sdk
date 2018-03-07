//
//  OCXMLParser.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCXMLParser.h"
#import "OCLogger.h"
#import "OCXMLParserElement.h"

@implementation OCXMLParser

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_elementParserClassByElementName = [NSMutableDictionary new];
		_valueConverterByElementName = [NSMutableDictionary new];

		_stack = [NSMutableArray new];
		_elementPath = [NSMutableArray new];

		_elementContents = [NSMutableArray new];
		_elementAttributes = [NSMutableArray new];
		_elementContentsEmptyIndexes = [NSMutableIndexSet new];
		_elementContentsLastIndex = -1;

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
	if (_insideElement)
	{
		OCXMLElementParser elementParser = nil;
		NSError *error = nil;
		
		if ([[_stack lastObject] respondsToSelector:@selector(xmlParser:childForElementName:namespaceURI:attributes:error:)])
		{
			elementParser = [[_stack lastObject] xmlParser:self childForElementName:elementName namespaceURI:namespaceURI attributes:attributeDict error:&error];
		}
		else
		{
			elementParser = [self defaultChildForElementName:elementName namespaceURI:namespaceURI attributes:attributeDict error:&error];
		}

		if ((elementParser == nil) && (error != nil))
		{
			[_errors addObject:error];
		}
	}
	
	[_elementPath addObject:elementName];

	[_elementAttributes addObject:((attributeDict!=nil) ? attributeDict : @{})];
	
	[_elementContents addObject:[NSMutableString string]];
	_elementContentsLastIndex++;
	[_elementContentsEmptyIndexes addIndex:_elementContentsLastIndex];
	
	_insideElement = YES;
}

- (OCXMLElementParser)defaultChildForElementName:(NSString *)elementName namespaceURI:(NSString *)namespaceURI attributes:(NSDictionary <NSString*,NSString*> *)attributes error:(NSError **)outError
{
	Class elementParserClass;
	OCXMLElementParser elementParser = nil;

	elementParserClass = [_elementParserClassByElementName objectForKey:elementName];

	if (elementParserClass == Nil)
	{
		elementParserClass = [OCXMLParserElement class];
	}

	if (elementParserClass != Nil)
	{
		NSError *error = nil;

		if ((elementParser = [[elementParserClass alloc] initWithXMLParser:self elementName:elementName namespaceURI:namespaceURI attributes:attributes error:&error]) != nil)
		{
			[_stack addObject:elementParser];
		}
		else if (error != nil)
		{
			[_errors addObject:error];
		}
	}
	
	return (elementParser);
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	[[_elementContents lastObject] appendString:string];
	[_elementContentsEmptyIndexes removeIndex:_elementContentsLastIndex];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	if (_insideElement)
	{
		NSString *elementContents = nil;
	
		if (![_elementContentsEmptyIndexes containsIndex:_elementContentsLastIndex])
		{
			elementContents = [_elementContents lastObject];
		}
	
		[[_stack lastObject] xmlParser:self parseKey:_elementPath.lastObject value:elementContents attributes:_elementAttributes.lastObject];
	}
	else
	{
		// Tell parser that its parsing has completed
		[[_stack lastObject] xmlParser:self completedParsingForChild:nil];
		
		// Tell parent that parsing of this child has completed
		if (_stack.count > 1)
		{
			[_stack[_stack.count-2] xmlParser:self completedParsingForChild:[_stack lastObject]];
		}
		else
		{
			NSLog(@"%@", [_stack lastObject]);
		}
		
		[_stack removeLastObject];
	}

	[_elementPath removeLastObject];

	if (_elementContentsLastIndex < -1) { _elementContentsLastIndex = -1; }
	[_elementAttributes removeLastObject];

	[_elementContents removeLastObject];
	[_elementContentsEmptyIndexes removeIndex:_elementContentsLastIndex];
	_elementContentsLastIndex--;

	_insideElement = NO;
}

@end
