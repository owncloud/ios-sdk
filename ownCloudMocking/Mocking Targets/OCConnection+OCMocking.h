//
//  OCConnection+OCMocking.h
//  ownCloudMocking
//
//  Created by Javier Gonzalez on 19/10/2018.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <ownCloudSDK/ownCloudSDK.h>
#import "OCMockManager.h"

@interface OCConnection (OCMocking)

- (void)ocm_prepareForSetupWithOptions:(NSDictionary<NSString *, id> *)options completionHandler:(void(^)(OCConnectionIssue *issue, NSURL *suggestedURL, NSArray <OCAuthenticationMethodIdentifier> *supportedMethods, NSArray <OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods))completionHandler;

- (void)ocm_generateAuthenticationDataWithMethod:(OCAuthenticationMethodIdentifier)methodIdentifier options:(OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(void(^)(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData))completionHandler;

@end

// Block and mock location for every mockable method
typedef void(^OCMockOCConnectionPrepareForSetupWithOptionsBlock)(NSDictionary<NSString *, id> *options, void(^completionHandler)(OCConnectionIssue *issue, NSURL *suggestedURL, NSArray <OCAuthenticationMethodIdentifier> *supportedMethods, NSArray <OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods));
extern OCMockLocation OCMockLocationOCConnectionPrepareForSetupWithOptions;

typedef void(^OCMockOCConnectionGenerateAuthenticationDataWithMethodBlock)(OCAuthenticationMethodIdentifier methodIdentifier, OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions options, void(^completionHandler)(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData));
extern OCMockLocation OCMockLocationOCConnectionGenerateAuthenticationDataWithMethod;
