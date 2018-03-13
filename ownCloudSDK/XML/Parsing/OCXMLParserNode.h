//
//  OCXMLParserNode.h
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


#import <Foundation/Foundation.h>

@class OCXMLParser;
@class OCXMLParserNode;

typedef NSDictionary<NSString*,void(^)(id target, NSString *key, id value)>*    OCXMLParserNodeKeyValueEnumeratorDictionary;
typedef NSDictionary<NSString*,void(^)(id target, OCXMLParserNode *childNode)>* OCXMLParserNodeChildNodesEnumeratorDictionary;

@interface OCXMLParserNode : NSObject
{
	NSString *_elementName;
	NSDictionary <NSString*,NSString*> *_attributes;

	NSMutableDictionary <NSString *, id> *_keyValues;
	NSMutableArray <OCXMLParserNode *> *_children;

	BOOL _retainChildren;
}

@property(strong) NSString *name;
@property(strong) NSDictionary <NSString*,NSString*> *attributes;
@property(strong) NSMutableDictionary <NSString *, id> *keyValues;
@property(strong) NSMutableArray <OCXMLParserNode *> *children;
@property(assign) BOOL retainChildren;

- (NSArray <OCXMLParserNode *> *)nodesForXPath:(NSString *)xPath;

- (void)enumerateChildNodesWithName:(NSString *)name usingBlock:(void(^)(OCXMLParserNode *childNode))handler;

- (void)enumerateChildNodesForTarget:(id)target withBlockForElementNames:(OCXMLParserNodeChildNodesEnumeratorDictionary)blockForElementNamesDict;
- (void)enumerateKeyValuesForTarget:(id)target withBlockForKeys:(OCXMLParserNodeKeyValueEnumeratorDictionary)blockForKeysDict;

- (instancetype)initWithXMLParser:(OCXMLParser *)xmlParser elementName:(NSString *)elementName namespaceURI:(NSString *)namespaceURI attributes:(NSDictionary <NSString*,NSString*> *)attributes error:(NSError **)outError;

- (NSError *)xmlParser:(OCXMLParser *)xmlParser parseKey:(NSString *)key value:(id)value attributes:(NSDictionary <NSString*,NSString*> *)attributes;

- (NSError *)xmlParser:(OCXMLParser *)xmlParser completedParsingForChild:(OCXMLParserNode *)child;

@end

#import "OCXMLParser.h"
