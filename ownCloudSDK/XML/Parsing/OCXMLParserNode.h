//
//  OCXMLParserNode.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@class OCXMLParser;

@interface OCXMLParserNode : NSObject
{
	NSString *_elementName;
	NSDictionary <NSString*,NSString*> *_attributes;

	NSMutableDictionary <NSString *, id> *_keyValues;
	NSMutableArray <OCXMLParserNode *> *_children;
	
	id _object;
}

@property(strong) NSString *name;
@property(strong) NSDictionary <NSString*,NSString*> *attributes;
@property(strong) NSMutableDictionary <NSString *, id> *keyValues;
@property(strong) NSMutableArray <OCXMLParserNode *> *children;
@property(strong) id object;

- (NSArray <OCXMLParserNode *> *)nodesForXPath:(NSString *)xPath;

- (instancetype)initWithXMLParser:(OCXMLParser *)xmlParser elementName:(NSString *)elementName namespaceURI:(NSString *)namespaceURI attributes:(NSDictionary <NSString*,NSString*> *)attributes error:(NSError **)outError;

- (NSError *)xmlParser:(OCXMLParser *)xmlParser parseKey:(NSString *)key value:(id)value attributes:(NSDictionary <NSString*,NSString*> *)attributes;

- (NSError *)xmlParser:(OCXMLParser *)xmlParser completedParsingForChild:(OCXMLParserNode *)child;

@end

#import "OCXMLParser.h"
