//
//  OCAppIdentity.m
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

#import "OCAppIdentity.h"

@implementation OCAppIdentity

@synthesize appIdentifierPrefix = _appIdentifierPrefix;

@synthesize keychainAccessGroupIdentifier = _keychainAccessGroupIdentifier;

@synthesize appGroupIdentifier = _appGroupIdentifier;
@synthesize appGroupContainerURL = _appGroupContainerURL;

@synthesize appName = _appName;

@synthesize keychain = _keychain;
@synthesize userDefaults = _userDefaults;

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
		_keychain = [[OCKeychain alloc] initWithAccessGroupIdentifier:((self.keychainAccessGroupIdentifier!=nil) ? ((self.appIdentifierPrefix!=nil) ? [self.appIdentifierPrefix stringByAppendingString:self.keychainAccessGroupIdentifier] : self.keychainAccessGroupIdentifier) : nil)];
	}
	
	return (_keychain);
}

- (NSUserDefaults *)userDefaults
{
	if (_userDefaults == nil)
	{
		if (self.appGroupIdentifier != nil)
		{
			_userDefaults = [[NSUserDefaults alloc] initWithSuiteName:self.appGroupIdentifier];
		}

		if (_userDefaults == nil)
		{
			_userDefaults = [NSUserDefaults standardUserDefaults];
		}
	}

	return (_userDefaults);
}

@end
