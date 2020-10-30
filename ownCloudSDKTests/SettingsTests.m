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

- (void)testMetadataAvailability
{
	NSURL *sdkDocsURL = [[NSBundle bundleForClass:self.class] URLForResource:@"class-settings-sdk" withExtension:nil];
	NSArray<Class> *scanClasses = @[
		OCCore.class,
		OCConnection.class,
		OCHTTPPipeline.class,
		OCAuthenticationMethodOAuth2.class,
		OCAuthenticationMethodOpenIDConnect.class,
		OCLogger.class,
		OCItemPolicyProcessor.class
	];

	NSString *missingMetadataList = @"";

	for (Class scanClass in scanClasses)
	{
		NSSet<OCClassSettingsKey> *keys = [OCClassSettings.sharedSettings keysForClass:scanClass];

		for (OCClassSettingsKey key in keys)
		{
			OCClassSettingsMetadata metadata;

			metadata = [OCClassSettings.sharedSettings metadataForClass:scanClass key:key options:@{
				OCClassSettingsMetadataOptionFillMissingValues : @(YES),
				OCClassSettingsMetadataOptionAddDefaultValue : @(YES),
				OCClassSettingsMetadataOptionExternalDocumentationFolders : @[
					sdkDocsURL
				]
			}];

			// Look for entries without metadata
			if (metadata == nil)
			{
				missingMetadataList = [missingMetadataList stringByAppendingFormat:@"\n- %@: %@", NSStringFromClass(scanClass), [NSString flatIdentifierFromIdentifier:[scanClass classSettingsIdentifier] key:key]];
			}

			OCLog(@"%@ -> %@", key, metadata);
		}
	}

	if (missingMetadataList.length > 0)
	{
		XCTFail(@"No metadata found for: %@", missingMetadataList);
	}
}

- (void)testUpdateConfigurationJSONFromMetadata
{
	NSURL *sdkDocsURL = [[NSBundle bundleForClass:self.class] URLForResource:@"class-settings-sdk" withExtension:nil];
	NSArray<NSDictionary<OCClassSettingsMetadataKey, id> *> *docDict;

	docDict = [OCClassSettings.sharedSettings documentationDictionaryWithOptions:@{
		OCClassSettingsDocumentationOptionExternalDocumentationFolders : @[ sdkDocsURL ],
		OCClassSettingsDocumentationOptionOnlyJSONTypes : @YES
	}];

	NSError *error = nil;
	NSData *jsonData;

	OCLogDebug(@"Doc Dict: %@", docDict);

	if ((jsonData = [NSJSONSerialization dataWithJSONObject:docDict options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys|NSJSONWritingFragmentsAllowed error:&error]) != nil)
	{
		OCLogDebug(@"JSON: %@", [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);

		NSString *jsonPath;

		if ((jsonPath = NSProcessInfo.processInfo.environment[@"OC_SETTINGS_DOC_JSON"]) != nil)
		{
			[jsonData writeToFile:jsonPath atomically:YES];
		}
	}
}

@end
