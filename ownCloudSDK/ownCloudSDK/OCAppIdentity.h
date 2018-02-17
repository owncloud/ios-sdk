//
//  OCAppIdentity.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

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
*/

@interface OCAppIdentity : NSObject
{
	NSString *_appIdentifierPrefix;
	NSString *_keychainAccessGroupIdentifier;
	NSString *_appGroupIdentifier;
	NSURL *_appGroupContainerURL;
	NSString *_appName;
	
	OCKeychain *_keychain;
}

#pragma mark - App Identifiers
@property(strong,nonatomic) NSString *appIdentifierPrefix;

@property(strong,nonatomic) NSString *keychainAccessGroupIdentifier;

@property(strong,nonatomic) NSString *appGroupIdentifier;

@property(strong,nonatomic) NSString *appName;

#pragma mark - App Paths
@property(strong,nonatomic) NSURL *appGroupContainerURL;

#pragma mark - App Resources
@property(strong,nonatomic) OCKeychain *keychain;

+ (instancetype)sharedAppIdentity;

@end
