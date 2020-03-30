//
//  OCSyncIssueTemplate.h
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
#import "OCSyncIssueChoice.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCSyncIssueTemplateIdentifier NS_TYPED_ENUM;

typedef NSString* OCSyncIssueTemplateOptionKey NS_TYPED_ENUM;
typedef NSDictionary<OCSyncIssueTemplateOptionKey,id>* OCSyncIssueTemplateOptions;

@interface OCSyncIssueTemplate : NSObject

#pragma mark - Template properties
@property(strong) OCSyncIssueTemplateIdentifier identifier;
@property(strong,nullable) NSString *categoryName;

@property(strong,nullable) NSArray<OCSyncIssueChoice *> *choices;

@property(strong,nullable) OCSyncIssueTemplateOptions options;

#pragma mark - Template creation
+ (instancetype)templateWithIdentifier:(OCSyncIssueTemplateIdentifier)identifier categoryName:(nullable NSString *)categoryName choices:(NSArray<OCSyncIssueChoice *> *)choices options:(nullable OCSyncIssueTemplateOptions)options;

#pragma mark - Template management
+ (void)registerTemplates:(NSArray<OCSyncIssueTemplate *> *)syncIssueTemplates;
+ (nullable OCSyncIssueTemplate *)templateForIdentifier:(OCSyncIssueTemplateIdentifier)templateIdentifier;
+ (nullable NSArray<OCSyncIssueTemplate *> *)templates;

@end

NS_ASSUME_NONNULL_END
