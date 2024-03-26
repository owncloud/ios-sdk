//
//  OCPasswordPolicyReport.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.02.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>

@class OCPasswordPolicyRule;

NS_ASSUME_NONNULL_BEGIN

@interface OCPasswordPolicyReport : NSObject

@property(readonly,strong) NSArray<OCPasswordPolicyRule *> *rules;
@property(readonly,nonatomic) BOOL passedValidation;

- (void)addRule:(OCPasswordPolicyRule *)rule result:(nullable NSString *)result;

- (BOOL)passedValidationForRule:(OCPasswordPolicyRule *)rule;
- (nullable NSString *)resultForRule:(OCPasswordPolicyRule *)rule;

@end

NS_ASSUME_NONNULL_END
