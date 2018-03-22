//
//  SettingsTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 22.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>

@interface SettingsTests : XCTestCase <OCClassSettingsSupport>

@end

@implementation SettingsTests

+ (OCClassSettingsIdentifier)classSettingsIdentifier;
{
	return (@"test");
}

+ (NSDictionary<OCClassSettingsKey, id> *)defaultSettingsForIdentifier:(OCClassSettingsIdentifier)identifier
{
	return @{
		@"test-value" : @"default"
	};
}

- (void)testSettingsOverride
{
	// Test default value
	XCTAssert ([[self classSettingForOCClassSettingsKey:@"test-value"] isEqual:@"default"], @"test-value is 'default'");

	// Add customSettings.plist
	[[OCClassSettings sharedSettings] addSource:[[OCClassSettingsFlatSourcePropertyList alloc] initWithURL:[[NSBundle bundleForClass:[self class]] URLForResource:@"customSettings" withExtension:@"plist"]]];

	// Test custom value
	XCTAssert ([[self classSettingForOCClassSettingsKey:@"test-value"] isEqual:@"custom"], @"test-value is 'custom': %@", [self classSettingForOCClassSettingsKey:@"test-value"]);
}

@end
