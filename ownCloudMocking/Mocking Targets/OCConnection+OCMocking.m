//
//  OCConnection+OCMocking.m
//  ownCloudMocking
//
//  Created by Javier Gonzalez on 19/10/2018.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2018, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCConnection+OCMocking.h"
#import "NSObject+OCSwizzle.h"

@implementation OCConnection (OCMocking)

+ (void)load
{
	[self addMockLocation:OCMockLocationOCConnectionPrepareForSetupWithOptions
		 forSelector:@selector(prepareForSetupWithOptions:completionHandler:)
					 with:@selector(ocm_prepareForSetupWithOptions:completionHandler:)];
	[self addMockLocation:OCMockLocationOCConnectionGenerateAuthenticationDataWithMethod
			  forSelector:@selector(generateAuthenticationDataWithMethod:options:completionHandler:)
					 with:@selector(ocm_generateAuthenticationDataWithMethod:options:completionHandler:)];
}

- (void)ocm_prepareForSetupWithOptions:(NSDictionary<NSString *, id> *)options completionHandler:(void(^)(OCIssue *issue, NSURL *suggestedURL, NSArray <OCAuthenticationMethodIdentifier> *supportedMethods, NSArray <OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods))completionHandler
{
	OCMockOCConnectionPrepareForSetupWithOptionsBlock mockBlock;

	if ((mockBlock = [[OCMockManager sharedMockManager] mockingBlockForLocation:OCMockLocationOCConnectionPrepareForSetupWithOptions]) != nil)
	{
		mockBlock(options, completionHandler);
	}
	else
	{
		[self ocm_prepareForSetupWithOptions:options completionHandler:completionHandler];
	}
}

- (void)ocm_generateAuthenticationDataWithMethod:(OCAuthenticationMethodIdentifier)methodIdentifier options:(OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(void(^)(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData))completionHandler
{
	OCMockOCConnectionGenerateAuthenticationDataWithMethodBlock mockBlock;

	if ((mockBlock = [[OCMockManager sharedMockManager] mockingBlockForLocation:OCMockLocationOCConnectionGenerateAuthenticationDataWithMethod]) != nil)
	{
		mockBlock(methodIdentifier, options, completionHandler);
	}
	else
	{
		[self ocm_generateAuthenticationDataWithMethod:methodIdentifier options:options completionHandler:completionHandler];
	}
}

OCMockLocation OCMockLocationOCConnectionPrepareForSetupWithOptions = @"OCConnection.prepareForSetupWithOptions";
OCMockLocation OCMockLocationOCConnectionGenerateAuthenticationDataWithMethod = @"OCConnection.generateAuthenticationDataWithMethod";

@end
