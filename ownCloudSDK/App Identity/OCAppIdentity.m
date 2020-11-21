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
#import "OCFeatureAvailability.h"

@implementation OCAppIdentity

@synthesize appIdentifierPrefix = _appIdentifierPrefix;

@synthesize keychainAccessGroupIdentifier = _keychainAccessGroupIdentifier;

@synthesize appGroupIdentifier = _appGroupIdentifier;
@synthesize appGroupContainerURL = _appGroupContainerURL;
@synthesize appGroupLogsContainerURL = _appGroupLogsContainerURL;

@synthesize appName = _appName;
@synthesize appDisplayName = _appDisplayName;

@synthesize componentIdentifier = _componentIdentifier;

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

			_componentIdentifier	   	   = bundleInfoDictionary[@"OCAppComponentIdentifier"];
			
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

- (NSURL *)appGroupLogsContainerURL
{
	if (_appGroupLogsContainerURL == nil)
	{
		_appGroupLogsContainerURL = [[self appGroupContainerURL] URLByAppendingPathComponent:@"logs"];
		if (![[NSFileManager defaultManager] fileExistsAtPath:[_appGroupLogsContainerURL path]])
		{
			[[NSFileManager defaultManager] createDirectoryAtURL:_appGroupLogsContainerURL
						 withIntermediateDirectories:NO
								  attributes:nil
								       error:nil];
		}
	}

	return (_appGroupLogsContainerURL);
}

- (NSString *)appName
{
	if (_appName == nil)
	{
		_appName = [[NSProcessInfo processInfo] processName];
	}
	
	return (_appName);
}

- (NSString *)appDisplayName
{
	if (_appDisplayName == nil)
	{
		_appDisplayName = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
	}

	return (_appDisplayName);
}

- (NSString *)appVersion
{
	if (_appVersion == nil)
	{
		_appVersion = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	}

	return (_appVersion);
}


- (NSString *)appBuildNumber
{
	if (_appBuildNumber == nil)
	{
		_appBuildNumber = [NSBundle.mainBundle objectForInfoDictionaryKey:(__bridge id)kCFBundleVersionKey];
	}

	return (_appBuildNumber);
}

- (NSString *)sdkCommit
{
	NSBundle *sdkBundle;
	NSString *commit = nil;

	if ((sdkBundle = [NSBundle bundleForClass:self.class]) != nil)
	{
		commit = [sdkBundle objectForInfoDictionaryKey:@"LastGitCommit"];
	}

	return ((commit != nil) ? commit : @"unknown");
}

- (NSString *)sdkVersionString
{
	NSBundle *sdkBundle;

	if ((sdkBundle = [NSBundle bundleForClass:self.class]) != nil)
	{
		return ([NSString stringWithFormat:@"%@ (%@) #%@",
				[sdkBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"], // Version
				[sdkBundle objectForInfoDictionaryKey:(__bridge NSString *)kCFBundleVersionKey], // Build version
				[self sdkCommit] // Last git commit
			]);
	}

	return (nil);
}

- (OCAppComponentIdentifier)componentIdentifier
{
	if (_componentIdentifier == nil)
	{
		_componentIdentifier = NSBundle.mainBundle.bundleIdentifier;
	}

	return (_componentIdentifier);
}

- (OCKeychain *)keychain
{
	if (_keychain == nil)
	{
		NSString *accessGroupIdentifier = ((self.keychainAccessGroupIdentifier!=nil) ? ((self.appIdentifierPrefix!=nil) ? [self.appIdentifierPrefix stringByAppendingString:self.keychainAccessGroupIdentifier] : self.keychainAccessGroupIdentifier) : nil);

		if (accessGroupIdentifier != nil)
		{
			_keychain = [[OCKeychain alloc] initWithAccessGroupIdentifier:accessGroupIdentifier];
		}
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

#pragma mark - Device/Environment/Build Capabilities
+ (BOOL)supportsFileProvider
{
	if (@available(iOS 14, *))
	{
		// File Provider should not be used if running as iOS App On Mac
		if (NSProcessInfo.processInfo.isiOSAppOnMac)
		{
			return (NO);
		}
	}

	#if OC_FEATURE_AVAILABLE_FILEPROVIDER
	return (YES);
	#else
	return (NO);
	#endif /* OC_FEATURE_AVAILABLE_FILEPROVIDER */
}

@end

OCAppComponentIdentifier OCAppComponentIdentifierApp = @"app";
OCAppComponentIdentifier OCAppComponentIdentifierFileProviderExtension = @"fileProviderExtension";
OCAppComponentIdentifier OCAppComponentIdentifierShareExtension = @"shareExtension";
