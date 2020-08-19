//
//  OCAppIdentity.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.02.18.
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

#import <Foundation/Foundation.h>
#import "OCKeychain.h"

/*
	OCAppIdentity groups information on an app's identifiers for use throughout the SDK (for keychain access, data shared between extensions and app, etc.).
 
	By default, the class tries to determine the values by looking for certain keys in the app's Info.plist, f.ex.:

	<key>OCAppIdentifierPrefix</key>
	<string>$(AppIdentifierPrefix)</string>

	<key>OCKeychainAccessGroupIdentifier</key>
	<string>com.owncloud.ios-client</string>

	<key>OCAppGroupIdentifier</key>
	<string>group.com.owncloud.ios-client</string>

	<key>OCAppComponentIdentifier</key>
	<string>[app|fileProviderExtension|shareExtension]</string>
*/

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCAppComponentIdentifier NS_TYPED_ENUM;

@interface OCAppIdentity : NSObject
{
	NSString *_appIdentifierPrefix;
	NSString *_keychainAccessGroupIdentifier;
	NSString *_appGroupIdentifier;
	NSURL *_appGroupContainerURL;
	NSURL *_appGroupLogsContainerURL;

	NSString *_appName;
	NSString *_appDisplayName;
	NSString *_appVersion;
	NSString *_appBuildNumber;

	OCKeychain *_keychain;
	NSUserDefaults *_userDefaults;
}

#pragma mark - App Identifiers
@property(strong,nonatomic,nullable) NSString *appIdentifierPrefix;

@property(strong,nonatomic,nullable) NSString *keychainAccessGroupIdentifier;

@property(strong,nonatomic,nullable) NSString *appGroupIdentifier;

@property(strong,nonatomic,nullable) NSString *appName;
@property(strong,nonatomic,nullable) NSString *appDisplayName;
@property(strong,nonatomic,nullable) NSString *appVersion;
@property(strong,nonatomic,nullable) NSString *appBuildNumber;

@property(strong,nonatomic,readonly,nullable) NSString *sdkCommit;
@property(strong,nonatomic,readonly,nullable) NSString *sdkVersionString;

#pragma mark - App Component
@property(strong,nonatomic,readonly,nullable) OCAppComponentIdentifier componentIdentifier;

#pragma mark - App Paths
@property(strong,nonatomic,nullable) NSURL *appGroupContainerURL;
@property(strong,nonatomic,nullable) NSURL *appGroupLogsContainerURL;

#pragma mark - App Resources
@property(strong,nonatomic,nullable) OCKeychain *keychain;
@property(strong,nonatomic,nullable) NSUserDefaults *userDefaults;

#pragma mark - Singleton
@property(class, readonly, strong, nonatomic) OCAppIdentity *sharedAppIdentity;

@end

extern OCAppComponentIdentifier OCAppComponentIdentifierApp;
extern OCAppComponentIdentifier OCAppComponentIdentifierFileProviderExtension;
extern OCAppComponentIdentifier OCAppComponentIdentifierShareExtension;

NS_ASSUME_NONNULL_END
