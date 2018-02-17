//
//  OCAppIdentity.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCAppIdentity.h"

@implementation OCAppIdentity

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

@synthesize appIdentifierPrefix = _appIdentifierPrefix;

@synthesize keychainAccessGroupIdentifier = _keychainAccessGroupIdentifier;

@synthesize appGroupIdentifier = _appGroupIdentifier;
@synthesize appGroupContainerURL = _appGroupContainerURL;

@synthesize appName = _appName;

@synthesize keychain = _keychain;

+ (instancetype)sharedAppIdentity
{
	static dispatch_once_t onceToken;
	static OCAppIdentity *sharedAppIdentity;

	dispatch_once(&onceToken, ^{
		sharedAppIdentity = [OCAppIdentity new];
	});
	
	return (sharedAppIdentity);
}

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		NSDictionary *bundleInfoDictionary;
		
		if ((bundleInfoDictionary = [[NSBundle mainBundle] infoDictionary]) != nil)
		{
			self.appIdentifierPrefix 	   = bundleInfoDictionary[@"OCAppIdentifierPrefix"];
			self.keychainAccessGroupIdentifier = bundleInfoDictionary[@"OCKeychainAccessGroupIdentifier"];
			self.appGroupIdentifier 	   = bundleInfoDictionary[@"OCAppGroupIdentifier"];
			
			self.appGroupContainerURL	   = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[self appGroupIdentifier]];
		}
	}
	
	return(self);
}

- (void)setAppGroupIdentifier:(NSString *)appGroupIdentifier
{
	self.appGroupContainerURL = nil;
	
	_appGroupIdentifier = appGroupIdentifier;
}

- (NSURL *)appGroupContainerURL
{
	if (_appGroupContainerURL == nil)
	{
		_appGroupContainerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:self.appGroupIdentifier];
	}
	
	return (_appGroupContainerURL);
}

- (NSString *)appName
{
	if (_appName == nil)
	{
		_appName = [[NSProcessInfo processInfo] processName];
	}
	
	return (_appName);
}

- (OCKeychain *)keychain
{
	if (_keychain == nil)
	{
		_keychain = [[OCKeychain alloc] initWithAccessGroupIdentifier:self.keychainAccessGroupIdentifier];
	}
	
	return (_keychain);
}

@end
