//
//  OCXMLParser.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>


/*
	Ground to cover:
	- list responses
	- share responses
	- exception responses
	- error responses
*/


@class OCXMLParser;
@protocol OCXMLElementParsing;

typedef id<OCXMLElementParsing> OCXMLElementParser;

@protocol OCXMLElementParsing <NSObject>

- (instancetype)initWithXMLParser:(OCXMLParser *)xmlParser elementName:(NSString *)elementName namespaceURI:(NSString *)namespaceURI attributes:(NSDictionary <NSString*,NSString*> *)attributes error:(NSError **)outError;

- (NSError *)xmlParser:(OCXMLParser *)xmlParser parseKey:(NSString *)key value:(NSString *)value attributes:(NSDictionary <NSString*,NSString*> *)attributes;

- (NSError *)xmlParser:(OCXMLParser *)xmlParser completedParsingForChild:(OCXMLElementParser)child;

@optional
- (OCXMLElementParser)xmlParser:(OCXMLParser *)xmlParser childForElementName:(NSString *)elementName namespaceURI:(NSString *)namespaceURI attributes:(NSDictionary <NSString*,NSString*> *)attributes error:(NSError **)outError;

@end

typedef NSError *(^OCXMLParserElementValueConverter)(NSString *elementName, NSString *value, id *convertedValue);

@interface OCXMLParser : NSObject <NSXMLParserDelegate>
{
	NSXMLParser *_xmlParser;

	NSMutableDictionary <NSString *, Class> *_elementParserClassByElementName;
	NSMutableDictionary <NSString *, OCXMLParserElementValueConverter> *_valueConverterByElementName;

	NSMutableArray <OCXMLElementParser> *_stack;

	NSMutableArray <NSString *> *_elementPath;
	NSMutableArray<NSDictionary<NSString *,NSString *> *> *_elementAttributes;

	NSMutableArray<NSMutableString *> *_elementContents;
	NSMutableIndexSet *_elementContentsEmptyIndexes;
	NSInteger _elementContentsLastIndex;
	
	BOOL _insideElement;

	NSMutableArray <NSError *> *_errors;

	NSMutableArray *_parsedObjects;
}

@property(readonly) NSMutableArray *parsedObjects;

- (instancetype)initWithParser:(NSXMLParser *)xmlParser;

#pragma mark - Parse
- (BOOL)parse;

@end
