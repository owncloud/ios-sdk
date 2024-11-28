//
//  OCCodeGenerator.h
//  ocapigen
//
//  Created by Felix Schwarz on 26.01.22.
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
#import "OCSchema.h"
#import "OCCodeFile.h"
#import "OCCodeFileSegment.h"

NS_ASSUME_NONNULL_BEGIN

@class OCCodeFile;

typedef NSString* OCCodeRawPropertyName;
typedef NSString* OCCodeNativePropertyName;

typedef NSString* OCCodeRawType;
typedef NSString* OCCodeRawFormat;
typedef NSString* OCCodeNativeType;

@interface OCCodeGenerator : NSObject

@property(strong) NSMutableDictionary<NSString *, OCSchema *> *schemaByPath;
@property(strong) NSURL *targetFolderURL;

@property(strong) NSString *segmentHeadLeadIn;
@property(strong,nullable) NSString *segmentHeadLeadOut;

@property(strong) NSMutableArray<OCCodeFile *> *files;

#pragma mark - Initialization
- (instancetype)initWithTargetFolder:(NSURL *)targetFolderURL;

#pragma mark - Add schemas
@property(strong,nullable,readonly,nonatomic) NSArray<OCSchema *> *allSchemas;
- (void)addSchema:(OCSchema *)schema;

#pragma mark - Request files
- (OCCodeFile *)fileForName:(NSString *)name;

#pragma mark - Type and Naming convention / conversion (for subclassing)
@property(readonly,nonatomic) NSDictionary<OCCodeRawType, OCCodeRawType> *rawToRawTypeMap; //!< Dictionary that maps raw types to "raw" types, i.e. "identityset" -> "IdentitySet", used by -nativeTypeForRAWType:
@property(readonly,nonatomic) NSDictionary<OCCodeRawType, OCCodeNativeType> *rawToNativeTypeMap; //!< Dictionary that maps raw types to native types, i.e. "string" -> "NSString", used by -nativeTypeForRAWType:
@property(readonly,nonatomic) NSDictionary<OCCodeRawPropertyName, OCCodeNativePropertyName> *rawToNativePropertyNameMap; //!< Dictionary that maps raw names to native names, i.e. "description" -> "desc", used by -nativeNameForProperty:
@property(readonly,nonatomic) BOOL nativeTypesUseCamelCase;
@property(readonly,nonatomic,nullable) NSString *nativeTypesPrefix;

- (nullable OCCodeNativeType)collectionTypeFor:(OCCodeNativeType)collectionType itemType:(OCCodeNativeType)itemType asReference:(BOOL)asReference inSegment:(nullable OCCodeFileSegment *)fileSegment; //!< Combines a collection and item type to a new type, i.e. NSArray and OCItem to NSArray<OCItem>.

- (OCCodeNativePropertyName)nativeNameForProperty:(OCSchemaProperty *)property inSegment:(nullable OCCodeFileSegment *)fileSegment; //!< Mapping of raw names to model property names, i.e. "description" -> "desc" for ObjC (where "description" is effectively reserved)
- (OCCodeNativeType)nativeTypeForRAWType:(OCCodeRawType)rawType rawFormat:(nullable OCCodeRawFormat)rawFormat rawItemType:(nullable OCCodeRawType)rawItemType asReference:(BOOL)asReference forProperty:(nullable OCSchemaProperty *)property inSegment:(nullable OCCodeFileSegment *)fileSegment; //!< Mapping of raw names to model types, i.e. "string" -> "NSString" (asReference=NO) + "NSString *" (asReference=YES)
- (OCCodeNativeType)nativeTypeForProperty:(OCSchemaProperty *)property asReference:(BOOL)asReference remappedFrom:(OCCodeNativeType _Nullable * _Nullable)outRemappedFrom inSegment:(nullable OCCodeFileSegment *)fileSegment; //!< Mapping of schema properties to model types, i.e. "array" -> "NSArray<NSString *>" (asReference=NO) + "NSArray<NSString *> *" (asReference=YES)
- (OCCodeNativeType)rawTypeForSchemaName:(NSString *)schemaName; //!< Formats a schema name as raw name for further processing (i.e. "odata.error.detail" -> "Odataerrordetail")
- (OCCodeNativeType)nativeTypeNameForSchema:(OCSchema *)schema inSegment:(nullable OCCodeFileSegment *)fileSegment; //!< Mapping of schema names to native model types, i.e. "user" -> "OCGUser"
- (BOOL)isGeneratedType:(OCCodeNativeType)type inSegment:(nullable OCCodeFileSegment *)fileSegment; //!< Returns YES if type is a generated type, i.e. to add forward declarations

#pragma mark - Code generation
- (void)generate;
- (void)generateForSchema:(OCSchema *)schema;

#pragma mark - Encode / Decode segment attribute line
- (nullable NSDictionary<OCCodeFileSegmentAttribute, id> *)decodeSegmentAttributesLine:(NSString *)line;
- (NSString *)encodeSegmentAttributesLineFrom:(OCCodeFileSegment *)segment;

@end

NS_ASSUME_NONNULL_END
