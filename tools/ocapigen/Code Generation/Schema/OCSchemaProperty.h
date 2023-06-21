//
//  OCSchemaProperty.h
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
#import "OCSchemaConstraint.h"
#import "OCYAMLNode.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCSchemaPropertyType NS_TYPED_ENUM;
typedef NSString* OCSchemaPropertyFormat;
typedef NSString* OCSchemaPropertyPattern;

@class OCSchema;

@interface OCSchemaProperty : NSObject

@property(weak) OCSchema *schema;
@property(strong) OCYAMLNode *yamlNode;

@property(strong) NSString *name;
@property(strong,nullable) OCSchemaPropertyType desc;

@property(strong) OCSchemaPropertyType type;
@property(strong,nullable) OCSchemaPropertyType itemType;
@property(strong,nullable) OCSchemaPropertyFormat format;
@property(strong,nullable) OCSchemaPropertyPattern pattern;

@property(readonly,nonatomic) BOOL isCollection;
@property(assign) BOOL required;

@property(strong) NSMutableArray<OCSchemaConstraint *> *constraints;

@end

NS_ASSUME_NONNULL_END
