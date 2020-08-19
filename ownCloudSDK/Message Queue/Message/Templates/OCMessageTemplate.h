//
//  OCMessageTemplate.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 30.03.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCMessageChoice.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCMessageTemplateIdentifier NS_TYPED_ENUM;

typedef NSString* OCMessageTemplateOptionKey NS_TYPED_ENUM;
typedef NSDictionary<OCMessageTemplateOptionKey,id>* OCMessageTemplateOptions;

@interface OCMessageTemplate : NSObject

#pragma mark - Template properties
@property(strong) OCMessageTemplateIdentifier identifier;
@property(strong,nullable) NSString *categoryName;

@property(strong,nullable) NSArray<OCMessageChoice *> *choices;

@property(strong,nullable) OCMessageTemplateOptions options;

#pragma mark - Template creation
+ (instancetype)templateWithIdentifier:(OCMessageTemplateIdentifier)identifier categoryName:(nullable NSString *)categoryName choices:(NSArray<OCMessageChoice *> *)choices options:(nullable OCMessageTemplateOptions)options;

#pragma mark - Template management
+ (void)registerTemplates:(NSArray<OCMessageTemplate *> *)syncIssueTemplates;
+ (nullable OCMessageTemplate *)templateForIdentifier:(OCMessageTemplateIdentifier)templateIdentifier;
+ (nullable NSArray<OCMessageTemplate *> *)templates;

@end

NS_ASSUME_NONNULL_END
