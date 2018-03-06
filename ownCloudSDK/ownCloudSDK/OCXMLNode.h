//
//  OCXMLNode.h
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

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, OCXMLNodeKind)
{
	OCXMLNodeKindDocument,
	OCXMLNodeKindElement,
	OCXMLNodeKindAttribute,
	OCXMLNodeKindNamespace,
	OCXMLNodeKindComment
};

@interface OCXMLNode : NSObject
{
	OCXMLNodeKind _kind;

	__weak OCXMLNode *_parent;
	
	NSMutableArray<OCXMLNode *> *_children;
	NSMutableArray<OCXMLNode *> *_attributes;

	NSString *_name;

	id _objectValue;
	NSString *_stringValue;
}

@property(assign) OCXMLNodeKind kind;

@property(weak) OCXMLNode *parent;
@property(strong,nonatomic) NSMutableArray<OCXMLNode *> *children;
@property(strong,nonatomic) NSMutableArray<OCXMLNode *> *attributes;

@property(strong) NSString *name;

@property(strong,nonatomic) id objectValue;
@property(strong,nonatomic) NSString *stringValue;

+ (instancetype)documentWithRootElement:(OCXMLNode *)rootNode;

+ (instancetype)elementWithName:(NSString *)name;

+ (instancetype)elementWithName:(NSString *)name stringValue:(NSString *)stringValue;

+ (instancetype)elementWithName:(NSString *)name children:(NSArray <OCXMLNode *> *)children;

+ (instancetype)elementWithName:(NSString *)name attributes:(NSArray <OCXMLNode *> *)attributes children:(NSArray <OCXMLNode *> *)children;

+ (instancetype)elementWithName:(NSString *)name attributes:(NSArray <OCXMLNode *> *)attributes;

+ (instancetype)elementWithName:(NSString *)name attributes:(NSArray <OCXMLNode *> *)attributes stringValue:(NSString *)stringValue;

+ (instancetype)attributeWithName:(NSString *)name stringValue:(NSString *)stringValue;

+ (instancetype)namespaceWithName:(NSString *)name stringValue:(NSString *)stringValue;

+ (instancetype)commentWithContent:(NSString *)comment;

- (NSArray <OCXMLNode *> *)nodesForXPath:(NSString *)xPath;

- (void)addChild:(OCXMLNode *)child;
- (void)addChildren:(NSArray <OCXMLNode *> *)children;

- (void)removeChild:(OCXMLNode *)child;
- (void)removeFromParent;

- (NSString *)XMLString;
- (NSData *)XMLUTF8Data;

@end
