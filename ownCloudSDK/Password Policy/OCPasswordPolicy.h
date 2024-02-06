//
//  OCPasswordPolicy.h
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
@class OCPasswordPolicyReport;

NS_ASSUME_NONNULL_BEGIN

@interface OCPasswordPolicy : NSObject

@property(strong,nullable) NSArray<OCPasswordPolicyRule *> *rules; //!< The rules checked by this password policy

- (instancetype)initWithRules:(NSArray<OCPasswordPolicyRule *> *)rules; //!< Initialize a new password policy with the provided array of rules
- (OCPasswordPolicyReport *)validate:(NSString *)password; //!< Validates the passed password and returns a report

@end

NS_ASSUME_NONNULL_END
