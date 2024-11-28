//
//  OCYAMLNode.h
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

typedef NSString* OCYAMLPath;
typedef NSString* OCYAMLReference;

NS_ASSUME_NONNULL_BEGIN

#define OCTypedCast(var,className) ([var isKindOfClass:[className class]] ? ((className *)var) : nil)

@interface OCYAMLNode : NSObject

@property(weak,nullable) OCYAMLNode *parentNode;

@property(assign) NSUInteger indentLevel;

@property(strong,readonly) NSString *name;
@property(strong,nullable) id value;

@property(strong) NSMutableDictionary<NSString *, OCYAMLNode *> *childrenByName;
@property(strong) NSMutableArray<OCYAMLNode *> *children;

@property(strong,readonly,nonatomic) OCYAMLPath path;

- (instancetype)initWithName:(NSString *)name value:(nullable id)value;
- (void)addChild:(OCYAMLNode *)child;

@end

NS_ASSUME_NONNULL_END
