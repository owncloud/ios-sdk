//
//  SettingsTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 22.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>

@interface TestSettingsSource : NSObject <OCClassSettingsSource>

@property(strong,nonatomic) NSDictionary<OCClassSettingsIdentifier, NSDictionary<OCClassSettingsKey, id> *> *injectedSettings;

@end

@implementation TestSettingsSource

- (OCClassSettingsSourceIdentifier)settingsSourceIdentifier
{
	return (@"test");
}

+ (instancetype)withSettingsDictionary:(NSDictionary<OCClassSettingsIdentifier, NSDictionary<OCClassSettingsKey, id> *> *)settings
{
	TestSettingsSource *testSource = [self new];

	testSource.injectedSettings = settings;

	return (testSource);
}

- (NSDictionary<OCClassSettingsKey,id> *)settingsForIdentifier:(OCClassSettingsIdentifier)identifier
{
	return (_injectedSettings[identifier]);
}

@end

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

- (void)testMetadataSourceAdditionAndRemoval
{
	TestSettingsSource *settingsSource = [TestSettingsSource withSettingsDictionary:@{
		OCClassSettingsIdentifierLog : @{
			OCClassSettingsKeyLogLevel : @(OCLogLevelInfo)
		}
	}];

	// Save default value
	NSNumber *logLevelBefore = [OCLogger classSettingForOCClassSettingsKey:OCClassSettingsKeyLogLevel];
	XCTAssert((logLevelBefore != nil), @"No default log level");

	// Add source with value
	[[OCClassSettings sharedSettings] addSource:settingsSource];

	// Check effect of addition of source
	NSNumber *logLevelAfter = [OCLogger classSettingForOCClassSettingsKey:OCClassSettingsKeyLogLevel];

	XCTAssert((logLevelAfter != nil), @"No more log level");
	XCTAssert(![logLevelBefore isEqual:logLevelAfter], @"Application of test settings source failed (1): %@ == %@", logLevelBefore, logLevelAfter);
	XCTAssert([logLevelAfter isEqual:@(OCLogLevelInfo)], @"Application of test settings source failed (2): %@ != %@", logLevelBefore, @(OCLogLevelInfo));

	// Remove source
	[[OCClassSettings sharedSettings] removeSource:settingsSource];

	// Check effect of removal of source
	logLevelAfter = [OCLogger classSettingForOCClassSettingsKey:OCClassSettingsKeyLogLevel];
	XCTAssert([logLevelBefore isEqual:logLevelAfter], @"Removal of test settings source failed: %@ != %@", logLevelBefore, logLevelAfter);
}

- (void)testMetadataValidationWithRejection
{
	TestSettingsSource *settingsSource = [TestSettingsSource withSettingsDictionary:@{
		OCClassSettingsIdentifierLog : @{
			OCClassSettingsKeyLogLevel : @(1000)
		}
	}];

	// Save default value
	NSNumber *logLevelBefore = [OCLogger classSettingForOCClassSettingsKey:OCClassSettingsKeyLogLevel];
	XCTAssert((logLevelBefore != nil), @"No default log level");

	// Add source with invalid value
	[[OCClassSettings sharedSettings] addSource:settingsSource];

	// Check effect of addition of source
	NSNumber *logLevelAfter = [OCLogger classSettingForOCClassSettingsKey:OCClassSettingsKeyLogLevel];

	XCTAssert((logLevelAfter != nil), @"No more log level");
	XCTAssert([logLevelBefore isEqual:logLevelAfter], @"Test settings source applied: %@ != %@", logLevelBefore, logLevelAfter);
	XCTAssert(![logLevelAfter isEqual:@(1000)], @"Test settings source applied: %@ == %@", logLevelAfter, @(1000));

	// Remove source
	[[OCClassSettings sharedSettings] removeSource:settingsSource];

	// Check effect of removal of source
	logLevelAfter = [OCLogger classSettingForOCClassSettingsKey:OCClassSettingsKeyLogLevel];
	XCTAssert([logLevelBefore isEqual:logLevelAfter], @"Removal of test settings source failed: %@ != %@", logLevelBefore, logLevelAfter);
}

- (void)testMetadataValidationWithPreLayeredRejection
{
	TestSettingsSource *validSettingsSource = [TestSettingsSource withSettingsDictionary:@{
		OCClassSettingsIdentifierLog : @{
			OCClassSettingsKeyLogLevel : @(OCLogLevelInfo)
		}
	}];

	TestSettingsSource *invalidSettingsSource = [TestSettingsSource withSettingsDictionary:@{
		OCClassSettingsIdentifierLog : @{
			OCClassSettingsKeyLogLevel : @(1000)
		}
	}];

	// Save default value
	NSNumber *logLevelBefore = [OCLogger classSettingForOCClassSettingsKey:OCClassSettingsKeyLogLevel];
	XCTAssert((logLevelBefore != nil), @"No default log level");

	// Add sources with valid and invalid value - invalid value should be skipped
	[[OCClassSettings sharedSettings] addSource:validSettingsSource];
	[[OCClassSettings sharedSettings] addSource:invalidSettingsSource];

	// Check effect of addition of invalid source
	NSNumber *logLevelAfter = [OCLogger classSettingForOCClassSettingsKey:OCClassSettingsKeyLogLevel];

	XCTAssert((logLevelAfter != nil), @"No more log level");
	XCTAssert(![logLevelBefore isEqual:logLevelAfter], @"Valid test settings source not applied: %@ == %@", logLevelBefore, logLevelAfter);
	XCTAssert([logLevelAfter isEqual:@(OCLogLevelInfo)], @"Valid test settings source dropped: %@ != %@", logLevelAfter, @(OCLogLevelInfo));
	XCTAssert(![logLevelAfter isEqual:@(1000)], @"Invalid test settings source applied: %@ == %@", logLevelAfter, @(1000));

	// Remove source
	[[OCClassSettings sharedSettings] removeSource:invalidSettingsSource];

	// Check effect of removal of source
	NSNumber *logLevelAfterRemoval = [OCLogger classSettingForOCClassSettingsKey:OCClassSettingsKeyLogLevel];
	XCTAssert([logLevelAfterRemoval isEqual:logLevelAfter], @"Removal of invalid test settings source failed: %@ != %@", logLevelAfterRemoval, logLevelAfter);

	// Clean up
	[[OCClassSettings sharedSettings] removeSource:validSettingsSource];
}

- (void)testMetadataValidationWithPostLayeredRejection
{
	TestSettingsSource *validSettingsSource = [TestSettingsSource withSettingsDictionary:@{
		OCClassSettingsIdentifierLog : @{
			OCClassSettingsKeyLogLevel : @(OCLogLevelInfo)
		}
	}];

	TestSettingsSource *invalidSettingsSource = [TestSettingsSource withSettingsDictionary:@{
		OCClassSettingsIdentifierLog : @{
			OCClassSettingsKeyLogLevel : @(1000)
		}
	}];

	// Save default value
	NSNumber *logLevelBefore = [OCLogger classSettingForOCClassSettingsKey:OCClassSettingsKeyLogLevel];
	XCTAssert((logLevelBefore != nil), @"No default log level");

	// Add sources with invalid and valid value - invalid value should be skipped
	[[OCClassSettings sharedSettings] addSource:invalidSettingsSource];
	[[OCClassSettings sharedSettings] addSource:validSettingsSource];

	// Check effect of addition of invalid source
	NSNumber *logLevelAfter = [OCLogger classSettingForOCClassSettingsKey:OCClassSettingsKeyLogLevel];

	XCTAssert((logLevelAfter != nil), @"No more log level");
	XCTAssert(![logLevelBefore isEqual:logLevelAfter], @"Valid test settings source not applied: %@ == %@", logLevelBefore, logLevelAfter);
	XCTAssert([logLevelAfter isEqual:@(OCLogLevelInfo)], @"Valid test settings source dropped: %@ != %@", logLevelAfter, @(OCLogLevelInfo));
	XCTAssert(![logLevelAfter isEqual:@(1000)], @"Invalid test settings source applied: %@ == %@", logLevelAfter, @(1000));

	// Remove source
	[[OCClassSettings sharedSettings] removeSource:invalidSettingsSource];

	// Check effect of removal of source
	NSNumber *logLevelAfterRemoval = [OCLogger classSettingForOCClassSettingsKey:OCClassSettingsKeyLogLevel];
	XCTAssert([logLevelAfterRemoval isEqual:logLevelAfter], @"Removal of invalid test settings source failed: %@ != %@", logLevelAfterRemoval, logLevelAfter);

	// Clean up
	[[OCClassSettings sharedSettings] removeSource:validSettingsSource];
}

- (void)testMetadataValidationWithSyncRejectionLogging
{
	// This test tests that logging an error in validation does not deadlock outside of log-related settings (which have their special log scheduling), either
	TestSettingsSource *invalidSettingsSource = [TestSettingsSource withSettingsDictionary:@{
		OCClassSettingsIdentifierConnection : @{
			OCConnectionAllowedAuthenticationMethodIDs : @[ @"urandom" ]
		},

		OCClassSettingsIdentifierLog : @{
			OCClassSettingsKeyLogLevel : @(OCLogLevelVerbose)
		}
	}];

	// Save default value
	NSArray<OCAuthenticationMethodIdentifier> *allowedBefore = [OCConnection classSettingForOCClassSettingsKey:OCConnectionAllowedAuthenticationMethodIDs];
	XCTAssert((allowedBefore == nil), @"Allowed before has values");

	// Add sources with invalid and valid value - invalid value should be skipped
	[[OCClassSettings sharedSettings] addSource:invalidSettingsSource];

	// Check effect of addition of invalid source
	NSArray<OCAuthenticationMethodIdentifier> *allowedAfter = [OCConnection classSettingForOCClassSettingsKey:OCConnectionAllowedAuthenticationMethodIDs];

	XCTAssert((allowedAfter == nil), @"Allowed after has value: %@", allowedAfter);

	// Remove source
	[[OCClassSettings sharedSettings] removeSource:invalidSettingsSource];
}

- (void)testMetadataValidationWithValueConversion
{
	TestSettingsSource *settingsSource = [TestSettingsSource withSettingsDictionary:@{
		OCClassSettingsIdentifierLog : @{
			OCClassSettingsKeyLogLevel : @(OCLogLevelInfo).stringValue
		}
	}];

	// Save default value
	NSNumber *logLevelBefore = [OCLogger classSettingForOCClassSettingsKey:OCClassSettingsKeyLogLevel];
	XCTAssert((logLevelBefore != nil), @"No default log level");

	// Add source with value
	[[OCClassSettings sharedSettings] addSource:settingsSource];

	// Check effect of addition of source
	NSNumber *logLevelAfter = [OCLogger classSettingForOCClassSettingsKey:OCClassSettingsKeyLogLevel];

	XCTAssert((logLevelAfter != nil), @"No more log level");
	XCTAssert(![logLevelBefore isEqual:logLevelAfter], @"Application of test settings source failed (1): %@ == %@", logLevelBefore, logLevelAfter);
	XCTAssert([logLevelAfter isEqual:@(OCLogLevelInfo)], @"Application of test settings source failed (2): %@ != %@", logLevelBefore, @(OCLogLevelInfo));

	// Remove source
	[[OCClassSettings sharedSettings] removeSource:settingsSource];

	// Check effect of removal of source
	logLevelAfter = [OCLogger classSettingForOCClassSettingsKey:OCClassSettingsKeyLogLevel];
	XCTAssert([logLevelBefore isEqual:logLevelAfter], @"Removal of test settings source failed: %@ != %@", logLevelBefore, logLevelAfter);
}

- (void)testMetadataTrailingAutoExpansion
{
	NSMutableDictionary<OCClassSettingsKey, id> *autoExpandSettings = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		@[ @"openid-connect" ], OCConnectionAllowedAuthenticationMethodIDs,
	nil];

	NSDictionary<OCClassSettingsKey, NSError *> *errors;

	OCLogDebug(@"Before validation: %@", autoExpandSettings);

	XCTAssert([[autoExpandSettings[OCConnectionAllowedAuthenticationMethodIDs] firstObject] isEqual:@"openid-connect"], @"Test value not consistent");

	errors = [OCClassSettings.sharedSettings validateDictionary:autoExpandSettings forClass:OCConnection.class updateCache:NO];

	OCLogDebug(@"After validation: %@", autoExpandSettings);

	XCTAssert((errors.count == 0), @"Unexpected error while trying to expand: %@", errors);
	XCTAssert([[autoExpandSettings[OCConnectionAllowedAuthenticationMethodIDs] firstObject] isEqual:OCAuthenticationMethodIdentifierOpenIDConnect], @"Test value not expanded: %@", autoExpandSettings);
}

- (void)testMetadataFlags
{
	NSNumber *savedLogLevel = [OCLogger classSettingForOCClassSettingsKey:OCClassSettingsKeyLogLevel];

	XCTAssert([OCLogger setUserPreferenceValue:savedLogLevel forClassSettingsKey:OCClassSettingsKeyLogLevel], @"Changing log level didn't work (despite allowed in metadata flags)");
	XCTAssert(![OCLogger setUserPreferenceValue:nil forClassSettingsKey:OCClassSettingsKeyLogMaximumLogMessageSize], @"Changing max log message size did work (despite denied in metadata flags)");
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
		NSSet<OCClassSettingsKey> *keys = [OCClassSettings.sharedSettings keysForClass:scanClass options:OCClassSettingsKeySetOptionDefault];

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

- (void)testAllowUserPreferences
{
	TestSettingsSource *settingsSource = [TestSettingsSource withSettingsDictionary:@{
		OCClassSettingsIdentifierUserPreferences : @{
			OCClassSettingsKeyUserPreferencesAllow : @[
				[NSString flatIdentifierFromIdentifier:OCClassSettingsIdentifierLog key:OCClassSettingsKeyLogLevel]
			]
		}
	}];

	XCTAssert([OCLogger userAllowedToSetPreferenceValueForClassSettingsKey:OCClassSettingsKeyLogLevel]);
	XCTAssert([OCConnection userAllowedToSetPreferenceValueForClassSettingsKey:OCConnectionForceBackgroundURLSessions]);
	XCTAssert(![OCLogger userAllowedToSetPreferenceValueForClassSettingsKey:OCClassSettingsKeyLogPrivacyMask]);

	// Add source with value
	[[OCClassSettings sharedSettings] addSource:settingsSource];

	// Check effect of addition of source
	XCTAssert([OCLogger userAllowedToSetPreferenceValueForClassSettingsKey:OCClassSettingsKeyLogLevel]);
	XCTAssert(![OCConnection userAllowedToSetPreferenceValueForClassSettingsKey:OCConnectionForceBackgroundURLSessions]);
	XCTAssert(![OCLogger userAllowedToSetPreferenceValueForClassSettingsKey:OCClassSettingsKeyLogPrivacyMask]);

	// Remove source
	[[OCClassSettings sharedSettings] removeSource:settingsSource];

	// Check effect of removal of source
	XCTAssert([OCLogger userAllowedToSetPreferenceValueForClassSettingsKey:OCClassSettingsKeyLogLevel]);
	XCTAssert([OCConnection userAllowedToSetPreferenceValueForClassSettingsKey:OCConnectionForceBackgroundURLSessions]);
	XCTAssert(![OCLogger userAllowedToSetPreferenceValueForClassSettingsKey:OCClassSettingsKeyLogPrivacyMask]);
}

- (void)testDenyUserPreferences
{
	TestSettingsSource *settingsSource = [TestSettingsSource withSettingsDictionary:@{
		OCClassSettingsIdentifierUserPreferences : @{
			OCClassSettingsKeyUserPreferencesDisallow : @[
				[NSString flatIdentifierFromIdentifier:OCClassSettingsIdentifierLog key:OCClassSettingsKeyLogLevel]
			]
		}
	}];

	XCTAssert([OCLogger userAllowedToSetPreferenceValueForClassSettingsKey:OCClassSettingsKeyLogLevel]);
	XCTAssert([OCConnection userAllowedToSetPreferenceValueForClassSettingsKey:OCConnectionForceBackgroundURLSessions]);
	XCTAssert(![OCLogger userAllowedToSetPreferenceValueForClassSettingsKey:OCClassSettingsKeyLogPrivacyMask]);

	// Add source with value
	[[OCClassSettings sharedSettings] addSource:settingsSource];

	// Check effect of addition of source
	XCTAssert(![OCLogger userAllowedToSetPreferenceValueForClassSettingsKey:OCClassSettingsKeyLogLevel]);
	XCTAssert([OCConnection userAllowedToSetPreferenceValueForClassSettingsKey:OCConnectionForceBackgroundURLSessions]);
	XCTAssert(![OCLogger userAllowedToSetPreferenceValueForClassSettingsKey:OCClassSettingsKeyLogPrivacyMask]);

	// Remove source
	[[OCClassSettings sharedSettings] removeSource:settingsSource];

	// Check effect of removal of source
	XCTAssert([OCLogger userAllowedToSetPreferenceValueForClassSettingsKey:OCClassSettingsKeyLogLevel]);
	XCTAssert([OCConnection userAllowedToSetPreferenceValueForClassSettingsKey:OCConnectionForceBackgroundURLSessions]);
	XCTAssert(![OCLogger userAllowedToSetPreferenceValueForClassSettingsKey:OCClassSettingsKeyLogPrivacyMask]);
}

- (void)testAllowDenyChangeObservation
{
	TestSettingsSource *settingsSource = [TestSettingsSource withSettingsDictionary:@{
		OCClassSettingsIdentifierUserPreferences : @{
			OCClassSettingsKeyUserPreferencesDisallow : @[
				[NSString flatIdentifierFromIdentifier:OCClassSettingsIdentifierLog key:OCClassSettingsKeyLogLevel]
			]
		}
	}];
	XCTestExpectation *expectInitialAllow = [self expectationWithDescription:@"Initial allow"];
	__block XCTestExpectation *expectAllowChangeOne = [self expectationWithDescription:@"Follow-up deny"];
	__block XCTestExpectation *expectAllowChangeTwo = [self expectationWithDescription:@"Follow-up allow"];

	OCClassSetting *setting = [OCLogger classSettingForKey:OCClassSettingsKeyLogLevel];

	[setting addObserver:^(id  _Nonnull owner, OCClassSetting * _Nonnull setting, OCClassSettingChangeType type, id  _Nullable oldValue, id  _Nullable newValue) {
		if (type & OCClassSettingChangeTypeInitial)
		{
			XCTAssert(setting.isUserConfigurable);
			[expectInitialAllow fulfill];
		}

		if (type & OCClassSettingChangeTypeIsUserConfigurable)
		{
			if ((expectAllowChangeOne != nil) && !setting.isUserConfigurable)
			{
				[expectAllowChangeOne fulfill];
				expectAllowChangeOne = nil;
			}

			if ((expectAllowChangeOne == nil) && (expectAllowChangeTwo != nil) && setting.isUserConfigurable)
			{
				[expectAllowChangeTwo fulfill];
				expectAllowChangeTwo = nil;
			}
		}
	} withOwner:self];

	XCTAssert(setting.isUserConfigurable);

	// Add source with value
	[[OCClassSettings sharedSettings] addSource:settingsSource];

	// Check effect of addition of source
	XCTAssert(!setting.isUserConfigurable);

	// Remove source
	[[OCClassSettings sharedSettings] removeSource:settingsSource];

	// Check effect of removal of source
	XCTAssert(setting.isUserConfigurable);

	[self waitForExpectationsWithTimeout:10 handler:nil];
}

- (void)testValueChangeObservation
{
	TestSettingsSource *settingsSource = [TestSettingsSource withSettingsDictionary:@{
		OCClassSettingsIdentifierLog : @{
			OCClassSettingsKeyLogLevel : @(OCLogLevelVerbose)
		}
	}];
	XCTestExpectation *expectInitialValue = [self expectationWithDescription:@"Initial value"];
	__block XCTestExpectation *expectValueChange1 = [self expectationWithDescription:@"Value change"];
	__block XCTestExpectation *expectValueChange2 = [self expectationWithDescription:@"Value reversal"];

	OCClassSetting *setting = [OCLogger classSettingForKey:OCClassSettingsKeyLogLevel];

	[setting addObserver:^(id  _Nonnull owner, OCClassSetting * _Nonnull setting, OCClassSettingChangeType type, id  _Nullable oldValue, id  _Nullable newValue) {
		NSLog(@"Change type: %ld, old: %@, new: %@", type, oldValue, newValue);

		if (type & OCClassSettingChangeTypeInitial)
		{
			XCTAssert(oldValue == nil);
			XCTAssert(![newValue isEqual:@(OCLogLevelVerbose)]);
			[expectInitialValue fulfill];
		}

		if (type & OCClassSettingChangeTypeValue)
		{
			if ((expectValueChange1 != nil) && [newValue isEqual:@(OCLogLevelVerbose)])
			{
				[expectValueChange1 fulfill];
				expectValueChange1 = nil;
			}

			if ((expectValueChange1 == nil) && (expectValueChange2 != nil) && ![newValue isEqual:@(OCLogLevelVerbose)])
			{
				[expectValueChange2 fulfill];
				expectValueChange2 = nil;
			}
		}
	} withOwner:self];

	// Add source with value
	[[OCClassSettings sharedSettings] addSource:settingsSource];

	// Remove source
	[[OCClassSettings sharedSettings] removeSource:settingsSource];

	[self waitForExpectationsWithTimeout:10 handler:nil];
}

@end
