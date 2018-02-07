//
//  OCAppIdentity.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

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

@property(strong,nonatomic) NSString *appIdentifierPrefix;

@property(strong,nonatomic) NSString *keychainAccessGroupIdentifier;

@property(strong,nonatomic) NSString *appGroupIdentifier;
@property(strong,nonatomic) NSURL *appGroupContainerURL;

+ (instancetype)sharedAppIdentity;

@end
