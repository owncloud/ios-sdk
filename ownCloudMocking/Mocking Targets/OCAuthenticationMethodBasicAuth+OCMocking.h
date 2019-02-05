//
//  OCAuthenticationMethodBasicAuth+OCMocking.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 12.07.18.
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

#import <ownCloudSDK/ownCloudSDK.h>
#import "OCMockManager.h"

@interface OCAuthenticationMethodBasicAuth (OCMocking)

// Counterparts of mockable methods
+ (void)ocm_ba_detectAuthenticationMethodSupportForConnection:(OCConnection *)connection withServerResponses:(NSDictionary<NSURL *, OCHTTPRequest *> *)serverResponses options:(OCAuthenticationMethodDetectionOptions)options completionHandler:(void(^)(OCAuthenticationMethodIdentifier identifier, BOOL supported))completionHandler;

- (void)ocm_ba_generateBookmarkAuthenticationDataWithConnection:(OCConnection *)connection options:(OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(void(^)(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData))completionHandler;

- (void)ocm_ba_authenticateConnection:(OCConnection *)connection withCompletionHandler:(OCAuthenticationMethodAuthenticationCompletionHandler)completionHandler;

- (void)ocm_ba_deauthenticateConnection:(OCConnection *)connection withCompletionHandler:(OCAuthenticationMethodAuthenticationCompletionHandler)completionHandler;

@end

// Block and mock location for every mockable method
typedef void(^OCMockAuthenticationMethodBasicAuthDetectAuthenticationMethodSupportForConnectionBlock)(OCConnection *connection, NSDictionary<NSURL *, OCHTTPRequest *> *serverResponses, OCAuthenticationMethodDetectionOptions options, void(^completionHandler)(OCAuthenticationMethodIdentifier identifier, BOOL supported));
extern OCMockLocation OCMockLocationAuthenticationMethodBasicAuthDetectAuthenticationMethodSupportForConnection;

typedef void(^OCMockAuthenticationMethodBasicAuthGenerateBookmarkAuthenticiationDataWithConnectionBlock)(OCConnection *connection, OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions options, void(^completionHandler)(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData));
extern OCMockLocation OCMockLocationAuthenticationMethodBasicAuthGenerateBookmarkAuthenticiationDataWithConnection;

typedef void(^OCMockAuthenticationMethodBasicAuthAuthenticateConnectionBlock)(OCConnection *connection, OCAuthenticationMethodAuthenticationCompletionHandler completionHandler);
extern OCMockLocation OCMockLocationAuthenticationMethodBasicAuthAuthenticateConnection;

typedef void(^OCMockAuthenticationMethodBasicAuthDeauthenticateConnectionBlock)(OCConnection *connection, OCAuthenticationMethodAuthenticationCompletionHandler completionHandler);
extern OCMockLocation OCMockLocationAuthenticationMethodBasicAuthDeauthenticateConnection;
