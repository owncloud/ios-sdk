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
@class OCXMLParserNode;

@protocol OCXMLObjectCreation <NSObject>

+ (instancetype)instanceFromNode:(OCXMLParserNode *)node xmlParser:(OCXMLParser *)xmlParser;

@end

typedef NSError *(^OCXMLParserElementValueConverter)(NSString *elementName, NSString *value, NSString *namespaceURI, NSDictionary <NSString*,NSString*> *attributes, id *convertedValue);

@interface OCXMLParser : NSObject <NSXMLParserDelegate>
{
	NSXMLParser *_xmlParser;

	NSMutableDictionary<NSString *, Class> *_objectCreationClassByElementName;
	NSMutableDictionary<NSString *, OCXMLParserElementValueConverter> *_valueConverterByElementName;

	NSMutableArray<OCXMLParserNode *> *_stack;

	NSMutableArray<NSString *> *_elementPath;
	NSMutableArray<NSDictionary<NSString *,NSString *> *> *_elementAttributes;

	NSMutableArray<NSMutableString *> *_elementContents;
	NSMutableIndexSet *_elementContentsEmptyIndexes;
	NSMutableIndexSet *_elementObjectifiedIndexes;
	NSInteger _elementContentsLastIndex;

	NSMutableArray<NSError *> *_errors;

	NSMutableArray *_parsedObjects;
}

@property(readonly) NSMutableArray *parsedObjects;

#pragma mark - Init & Dealloc
- (instancetype)initWithParser:(NSXMLParser *)xmlParser;

#pragma mark - Parse
- (BOOL)parse;

@end
