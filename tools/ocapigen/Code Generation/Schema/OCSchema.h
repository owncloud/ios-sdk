//
//  OCSchema.h
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
#import "OCSchemaProperty.h"
#import "OCYAMLNode.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCSchema : NSObject

@property(strong) NSString *name;
@property(strong,nullable) NSString *desc;

@property(strong) OCYAMLPath yamlPath;

@property(strong) NSMutableArray<OCSchemaProperty *> *properties;

- (instancetype)initWithYAMLNode:(OCYAMLNode *)node;

@end

NS_ASSUME_NONNULL_END
