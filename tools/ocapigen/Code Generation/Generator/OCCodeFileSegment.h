//
//  OCCodeFileSegment.h
//  ocapigen
//
//  Created by Felix Schwarz on 27.01.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>

@class OCCodeGenerator;
@class OCCodeFile;

typedef NSString* OCCodeFileSegmentName NS_TYPED_ENUM;

typedef NSString* OCCodeFileSegmentAttribute NS_TYPED_ENUM;

NS_ASSUME_NONNULL_BEGIN

@interface OCCodeFileSegment : NSObject

@property(weak,nullable) OCCodeGenerator *generator;
@property(weak,nullable) OCCodeFile *file;

@property(strong,nonatomic) OCCodeFileSegmentName name;

@property(assign,nonatomic) BOOL locked;

@property(strong,nullable,nonatomic) NSDictionary<OCCodeFileSegmentAttribute, id> *attributes;
@property(strong,nonatomic) NSString *attributeHeaderLine;

@property(strong) NSMutableArray<NSString *> *lines;

- (instancetype)initWithAttributeHeaderLine:(nullable NSString *)attributeHeaderLine name:(OCCodeFileSegmentName)name file:(OCCodeFile *)file generator:(OCCodeGenerator *)generator;

- (void)addLine:(NSString *)line, ... NS_FORMAT_FUNCTION(1,2);

- (instancetype)clear;
- (void)removeLastLineIfEmpty;

- (NSString *)composedSegment;
- (BOOL)hasContent;

@end

@interface OCCodeFileSegment (Internal)
- (void)_loadLine:(NSString *)line;
@end

extern OCCodeFileSegmentAttribute OCCodeFileSegmentAttributeName;
extern OCCodeFileSegmentAttribute OCCodeFileSegmentAttributeLocked;
extern OCCodeFileSegmentAttribute OCCodeFileSegmentAttributeCustomPropertyTypes;
extern OCCodeFileSegmentAttribute OCCodeFileSegmentAttributeCustomPropertyNames;

extern OCCodeFileSegmentName OCCodeFileSegmentNameLeadComment;
extern OCCodeFileSegmentName OCCodeFileSegmentNameIncludes;
extern OCCodeFileSegmentName OCCodeFileSegmentNameForwardDeclarations;
extern OCCodeFileSegmentName OCCodeFileSegmentNameTypeLeadIn;
extern OCCodeFileSegmentName OCCodeFileSegmentNameTypeSerialization;
extern OCCodeFileSegmentName OCCodeFileSegmentNameTypeNativeSerialization;
extern OCCodeFileSegmentName OCCodeFileSegmentNameTypeNativeDeserialization;
extern OCCodeFileSegmentName OCCodeFileSegmentNameTypeDebugDescription;
extern OCCodeFileSegmentName OCCodeFileSegmentNameTypeProperties;
extern OCCodeFileSegmentName OCCodeFileSegmentNameTypeProtected;
extern OCCodeFileSegmentName OCCodeFileSegmentNameTypeLeadOut;

NS_ASSUME_NONNULL_END
