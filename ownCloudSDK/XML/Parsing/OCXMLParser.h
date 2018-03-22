//
//  OCXMLParser.h
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

#import <Foundation/Foundation.h>

@class OCXMLParser;
@class OCXMLParserNode;

@protocol OCXMLObjectCreation <NSObject>

+ (NSString *)xmlElementNameForObjectCreation;
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

	NSInteger _objectCreationRetainDepth;
	BOOL _forceRetain;

	NSMutableArray<NSError *> *_errors;

	NSMutableArray *_parsedObjects;

	NSMutableDictionary <NSString *, id> *_options;
}

@property(readonly,strong) NSMutableArray<NSError *> *errors;
@property(readonly,strong) NSMutableArray *parsedObjects;

@property(assign) BOOL forceRetain;
@property(strong) NSMutableDictionary <NSString *, id> *options;

#pragma mark - Init & Dealloc
- (instancetype)initWithParser:(NSXMLParser *)xmlParser;
- (instancetype)initWithData:(NSData *)xmlData;

#pragma mark - Specify classes
- (void)addObjectCreationClasses:(NSArray <Class> *)classes;

#pragma mark - Parse
- (BOOL)parse;

@end
