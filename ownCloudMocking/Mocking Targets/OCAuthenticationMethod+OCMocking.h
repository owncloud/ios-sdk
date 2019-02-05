//
//  OCAuthenticationMethod+OCMocking.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 11.07.18.
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

@interface OCAuthenticationMethod (OCMocking)

// Counterparts of mockable methods
+ (void)ocm_detectAuthenticationMethodSupportForConnection:(OCConnection *)connection withServerResponses:(NSDictionary<NSURL *, OCHTTPRequest *> *)serverResponses options:(OCAuthenticationMethodDetectionOptions)options completionHandler:(void(^)(OCAuthenticationMethodIdentifier identifier, BOOL supported))completionHandler;

- (void)ocm_generateBookmarkAuthenticationDataWithConnection:(OCConnection *)connection options:(OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(void(^)(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData))completionHandler;

- (void)ocm_authenticateConnection:(OCConnection *)connection withCompletionHandler:(OCAuthenticationMethodAuthenticationCompletionHandler)completionHandler;

- (void)ocm_deauthenticateConnection:(OCConnection *)connection withCompletionHandler:(OCAuthenticationMethodAuthenticationCompletionHandler)completionHandler;

@end

// Block and mock location for every mockable method
typedef void(^OCMockAuthenticationMethodDetectAuthenticationMethodSupportForConnectionBlock)(OCConnection *connection, NSDictionary<NSURL *, OCHTTPRequest *> *serverResponses, OCAuthenticationMethodDetectionOptions options, void(^completionHandler)(OCAuthenticationMethodIdentifier identifier, BOOL supported));
extern OCMockLocation OCMockLocationAuthenticationMethodDetectAuthenticationMethodSupportForConnection;

typedef void(^OCMockAuthenticationMethodGenerateBookmarkAuthenticiationDataWithConnectionBlock)(OCConnection *connection, OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions options, void(^completionHandler)(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData));
extern OCMockLocation OCMockLocationAuthenticationMethodGenerateBookmarkAuthenticiationDataWithConnection;

typedef void(^OCMockAuthenticationMethodAuthenticateConnectionBlock)(OCConnection *connection, OCAuthenticationMethodAuthenticationCompletionHandler completionHandler);
extern OCMockLocation OCMockLocationAuthenticationMethodAuthenticateConnection;

typedef void(^OCMockAuthenticationMethodDeauthenticateConnectionBlock)(OCConnection *connection, OCAuthenticationMethodAuthenticationCompletionHandler completionHandler);
extern OCMockLocation OCMockLocationAuthenticationMethodDeauthenticateConnection;
