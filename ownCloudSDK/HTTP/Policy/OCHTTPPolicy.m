//
//  OCHTTPPolicy.m
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

#import "OCHTTPPolicy.h"

@implementation OCHTTPPolicy

- (instancetype)initWithIdentifier:(OCHTTPPolicyIdentifier)identifier
{
	if ((self = [super init]) != nil)
	{
		_identifier = identifier;
	}

	return (self);
}

- (void)validateCertificate:(nonnull OCCertificate *)certificate forRequest:(nonnull OCHTTPRequest *)request validationResult:(OCCertificateValidationResult)validationResult validationError:(nonnull NSError *)validationError proceedHandler:(nonnull OCConnectionCertificateProceedHandler)proceedHandler
{
	proceedHandler((validationResult == OCCertificateValidationResultPassed) || (validationResult == OCCertificateValidationResultUserAccepted), validationError);
}

#pragma mark - Secure coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if ((self = [self init]) != nil)
	{
		_identifier = [coder decodeObjectOfClass:NSString.class forKey:@"identifier"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_identifier forKey:@"identifier"];
}

#pragma mark - Log tags
+ (NSArray<OCLogTagName> *)logTags
{
	return (@[@"HTTP", @"Policy"]);
}

- (NSArray<OCLogTagName> *)logTags
{
	return (@[@"HTTP", @"Policy"]);
}

@end

OCHTTPPolicyIdentifier OCHTTPPolicyIdentifierConnection = @"connection";
