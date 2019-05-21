//
//  OCCertificateRuleChecker.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 12.04.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCCertificate.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCCertificateRuleChecker : NSObject

@property(strong) OCCertificate *certificate;
@property(nullable,strong) OCCertificate *otherCertificate;

@property(strong) NSString *rule;

#pragma mark - Creation
+ (instancetype)ruleWithCertificate:(OCCertificate *)certificate newCertificate:(nullable OCCertificate *)newCertificate rule:(NSString *)rule;

#pragma mark - Evaluation
- (void)evaluateRuleWithCompletionHandler:(void(^)(BOOL passedCheck))completionHandler; //!< Evaluates the provided rule and calls the completion handler when done.
- (BOOL)evaluateRule; //!< Helper method to evaluate the provided rule synchronously. Use the async version instead whenever possible.

#pragma mark - Computed values
- (BOOL)certificatesHaveIdenticalParents; //!< YES if the parents of both certificate and newCertificate are identical.
- (BOOL)parentCertificatesHaveIdenticalPublicKeys; //!< YES if the parents of both certificate and newCertificate have identical public keys.

@end

@interface OCCertificate (RuleChecker)

// These should only be used in the context of OCCertificateRuleChecker rules
- (NSString *)validationResult; //!< A string representation of the OCCertificateValidationResult: "error", "rejected", "promptUser", "passed", "userAccepted". Use only in context of OCCertificateRuleChecker rules.
- (BOOL)passedValidationOrIsUserAccepted; //!< Returns YES if validation finished with "passed" or "userAccepted".
- (NSData *)publicKeyData; //!< The bytes of the public key. Use only in context of OCCertificateRuleChecker rules.

@end

NS_ASSUME_NONNULL_END
