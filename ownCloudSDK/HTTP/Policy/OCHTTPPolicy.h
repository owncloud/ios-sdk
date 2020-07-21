//
//  OCHTTPPolicy.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.07.20.
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

/*
// OCHTTPPolicy should allow these things
// - access request before scheduling (to add credentials)
// - access request after certificate is known (to validate, apply custom policies)
// - handle response and provide an instruction (to re-queue requests with failed validation or network errors)
// - be fully serializable (for persistance in pipeline backend)

- (NSArray<OCHTTPPolicy *> *)policiesForPipeline:(OCHTTPPipeline *)pipeline; //!< Array of policies that need to be fulfilled to let a request be sent. Called automatically at every attach. Call -[OCPipeline policiesChangedForPartition:] while attached to ask OCHTTPPipeline to call this.

- (void)pipeline:(OCHTTPPipeline *)pipeline handlePolicy:(OCHTTPPolicy *)policy error:(NSError *)error; //!< Called whenever there is an error validating a security policy. Provides enough info to create an issue and the proceed handler allows reacting to it (f.ex. via error userinfo provide OCCertificate *certificate, BOOL userAcceptanceRequired, OCConnectionCertificateProceedHandler proceedHandler).
*/

#import <Foundation/Foundation.h>
#import "OCHTTPPipeline.h"
#import "OCHTTPRequest.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCHTTPPolicyIdentifier NS_TYPED_ENUM;

@interface OCHTTPPolicy : NSObject <OCLogTagging, NSSecureCoding>

@property(strong,readonly) OCHTTPPolicyIdentifier identifier;

- (instancetype)initWithIdentifier:(OCHTTPPolicyIdentifier)identifier;

- (void)validateCertificate:(nonnull OCCertificate *)certificate forRequest:(nonnull OCHTTPRequest *)request validationResult:(OCCertificateValidationResult)validationResult validationError:(nonnull NSError *)validationError proceedHandler:(nonnull OCConnectionCertificateProceedHandler)proceedHandler;

@end

extern OCHTTPPolicyIdentifier OCHTTPPolicyIdentifierConnection;

NS_ASSUME_NONNULL_END
