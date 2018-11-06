//
//  OCXMLParser.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.03.18.
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

#import "OCXMLParser.h"
#import "OCLogger.h"
#import "OCXMLParserNode.h"
#import "OCItem.h"
#import "OCHTTPStatus.h"
#import "NSDate+OCDateParser.h"

@implementation OCXMLParser

@synthesize options = _options;
@synthesize errors = _errors;
@synthesize parsedObjects = _parsedObjects;
@synthesize forceRetain = _forceRetain;

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

		// Convert <d:status> tags to OCHTTPStatus objects
		[_valueConverterByElementName setObject:^(NSString *elementName, NSString *value, NSString *namespaceURI, NSDictionary <NSString*,NSString*> *attributes, id *convertedValue){
			/*
				Examples:
				"HTTP/1.1 200 OK"
				"HTTP/1.1 404 Not Found"
			*/
			if (convertedValue==NULL) { return((NSError*)nil); }

			if ([value hasPrefix:@"HTTP/"])
			{
				NSRange firstSpaceRange = [value rangeOfString:@" "];

				if ((firstSpaceRange.location != NSNotFound) && (value.length >= 12))
				{
					NSString *statusCodeString;

					if ((statusCodeString = [value substringWithRange:NSMakeRange(9,3)]) != nil)
					{
						*convertedValue = [OCHTTPStatus HTTPStatusWithCode:statusCodeString.integerValue];
					}
				}
			}

			return((NSError*)nil);
		} forKey:@"d:status"];

		// Convert <d:getlastmodified> and <d:creationdate> to NSDate
		OCXMLParserElementValueConverter dateConverter = ^(NSString *elementName, NSString *value, NSString *namespaceURI, NSDictionary <NSString*,NSString*> *attributes, id *convertedValue){
			/*
				Examples:
				"Fri, 23 Feb 2018 11:52:05 GMT"
			*/
			NSDate *date = nil;

			if (convertedValue!=NULL)
			{
				if ((date = [NSDate dateParsedFromString:value error:NULL]) != nil)
				{
					*convertedValue = date;
				}
			}

			return((NSError*)nil);
		};
		[_valueConverterByElementName setObject:dateConverter forKey:@"d:getlastmodified"];
		[_valueConverterByElementName setObject:dateConverter forKey:@"d:creationdate"];
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

- (instancetype)initWithData:(NSData *)xmlData
{
	self = [self initWithParser:[[NSXMLParser alloc] initWithData:xmlData]];

	return(self);
}

- (void)dealloc
{
	_xmlParser.delegate = nil;
}

#pragma mark - Specify classes
- (void)addObjectCreationClasses:(NSArray <Class> *)classes
{
	if (classes != nil)
	{
		for (Class addClass in classes)
		{
			NSString *elementName;

			if ((elementName = [addClass xmlElementNameForObjectCreation]) != nil)
			{
				[_objectCreationClassByElementName setObject:addClass forKey:elementName];
			}
		}
	}
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

	if ([_objectCreationClassByElementName valueForKey:elementName] != nil)
	{
		_objectCreationRetainDepth++;
	}

	if ((elementNode = [[OCXMLParserNode alloc] initWithXMLParser:self elementName:elementName namespaceURI:namespaceURI attributes:attributeDict error:&error]) != nil)
	{
		[_stack addObject:elementNode];
	}
	else if (error != nil)
	{
		[_errors addObject:error];
	}

	elementNode.retainChildren = (_objectCreationRetainDepth > 0) || _forceRetain;
	
	[_elementPath addObject:elementName];

	[_elementAttributes addObject:((attributeDict!=nil) ? attributeDict : @{})];
	
	[_elementContents addObject:[NSMutableString new]];
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
			[_stack[_stack.count-2] xmlParser:self completedParsingForChild:lastParserElementOnStack];
		}
		else
		{
			// OCLogDebug(@"%@", lastParserElementOnStack);
			// OCLogDebug(@"%@", [(OCXMLParserNode *)lastParserElementOnStack nodesForXPath:@"d:response/d:propstat"]);
		}
	}

	// Create object if applicable
	Class objectCreationClass;

	if ((objectCreationClass = [_objectCreationClassByElementName valueForKey:elementName]) != nil)
	{
		// Try object creation
		id parsedObject;

		if ((parsedObject = [objectCreationClass instanceFromNode:lastParserElementOnStack xmlParser:self]) != nil)
		{
			if ([parsedObject isKindOfClass:[NSError class]])
			{
				[_errors addObject:parsedObject];
			}
			else
			{
				[_parsedObjects addObject:parsedObject];
			}
		}

		_objectCreationRetainDepth--;
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
