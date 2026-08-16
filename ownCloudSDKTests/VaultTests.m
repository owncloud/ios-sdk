//
//  VaultTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 15.08.26.
//  Copyright © 2026 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2026, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>

@interface MockVault: OCVault
@end

@implementation MockVault

+ (NSURL *)storageRootURL
{
	return ([NSURL fileURLWithPath:@"/tmp/ocsdk-tests/Vaults/"]);
}

- (NSURL *)filesRootURL
{
	return([MockVault.storageRootURL URLByAppendingPathComponent:_uuid.UUIDString isDirectory:YES]);
}

+ (NSURL *)rootURLForUUID:(NSUUID *)uuid
{
	return [[[NSURL fileURLWithPath:@"/tmp/ocsdk-tests/"] URLByAppendingPathComponent:OCVaultPathVaults] URLByAppendingPathComponent:[OCVault rootPathRelativeToGroupContainerForVaultUUID:uuid]];
}

@end

@interface VaultTests : XCTestCase
@end

@implementation VaultTests

- (void)testVaultDriveRootURL {
	OCBookmark *bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"https://demo.owncloud.com/"]];
	OCVault *vault = [[MockVault alloc] initWithBookmark:bookmark];
	NSString *drivesURLBaseString = [vault.rootURL.absoluteString stringByAppendingString:@"/Drives/"];

	// MockVault provides /tmp/ as rootURL
	XCTAssert([vault.rootURL.absoluteString hasPrefix:@"file:///tmp/ocsdk-tests/"]);

	NSDictionary<OCDriveID, NSString*> *expectedURLsbyDriveID = @{
		// normal oCIS drive ID
		@"166d1210-cdb9-50ab-9f1e-ecb9ef12a304$2e81b56f-9284-409a-9dd0-364604df62ce" : @"166d1210-cdb9-50ab-9f1e-ecb9ef12a304$2e81b56f-9284-409a-9dd0-364604df62ce",

		// driveID with umlauts and other special characters -> base64
		@"öäüÖÄÜß"	: @"b64,w7bDpMO8w5bDhMOcw58",
		@"éclaire"	: @"b64,w6ljbGFpcmU",

		// driveID with standard but oCIS-atypical characters -> base64
		@"abc%123" 	: @"b64,YWJjJTEyMw",
		@"abc_123" 	: @"b64,YWJjXzEyMw",
		@"abc*123" 	: @"b64,YWJjKjEyMw",
		@"abc#123" 	: @"b64,YWJjIzEyMw",
		@"abc.123" 	: @"b64,YWJjLjEyMw",
		@"abc/123" 	: @"b64,YWJjLzEyMw",
		@"abc//123" 	: @"b64,YWJjLy8xMjM",
		@"abc/..123" 	: @"b64,YWJjLy4uMTIz",
		@"abc/../123" 	: @"b64,YWJjLy4uLzEyMw",

		// long driveID (exceeding NAME_MAX (256))
		@"abcdefghijklmnopqrstuvwxyz-abcdefghijklmnopqrstuvwxyz-abcdefghijklmnopqrstuvwxyz-abcdefghijklmnopqrstuvwxyz-abcdefghijklmnopqrstuvwxyz-abcdefghijklmnopqrstuvwxyz-abcdefghijklmnopqrstuvwxyz-abcdefghijklmnopqrstuvwxyz-abcdefghijklmnopqrstuvwxyz-abcdefghijklmnopqrstuvwxyz" : @"s256,605c6b5d17e9882a3e50b2883c8a9e06ec51aedc3dca3ee04bcecaed4a2ca696",
	};

	for (OCDriveID driveID in expectedURLsbyDriveID) {
		// Test driveID -> drive root URL
		NSString *expectedURLString = [drivesURLBaseString stringByAppendingFormat:@"%@/", expectedURLsbyDriveID[driveID]];
		NSURL *actualURL = [vault localDriveRootURLForDriveID:driveID];
		NSString *actualURLString = [actualURL absoluteString];

		if ([actualURLString isEqual:expectedURLString]) {
			OCLog(@"localDriveRootURLForDriveID:%@ -> %@", driveID, actualURLString);
		} else {
			OCLogError(@"localDriveRootURLForDriveID:%@ -> '%@' (actual) != '%@' (expected)", driveID, actualURLString, expectedURLString);
		}

		XCTAssert((actualURLString != nil) && [actualURLString isEqual:expectedURLString]);

		// Test driveID -> encoded drive component
		BOOL isLossy = NO;
		NSString *expectedComponent = expectedURLsbyDriveID[driveID];
		NSString *actualComponent = [driveID encodedFilesystemCompatibleComponentIsLossy:&isLossy];

		if ([actualComponent isEqual:expectedComponent]) {
			OCLog(@"encodedOCFilesystemComponentIsLossy:%@ -> %@", driveID, actualComponent);
		} else {
			OCLogError(@"encodedOCFilesystemComponentIsLossy:%@ -> '%@' (actual) != '%@' (expected)", driveID, actualComponent, expectedComponent);
		}

		XCTAssert((actualComponent != nil) && [actualComponent isEqual:expectedComponent]);

		// Test encoded drive component -> driveID
		BOOL decodedIsLossy;
		NSString *decodedComponent = [actualComponent decodedFilesystemCompatibleComponentIsLossy:&decodedIsLossy];

		XCTAssert (decodedIsLossy == isLossy);
		XCTAssert (((decodedComponent != nil) && !decodedIsLossy) || ((decodedComponent == nil) && decodedIsLossy));

		if ([actualComponent hasPrefix:@"s256,"]) {
			XCTAssert(decodedIsLossy && isLossy);
		}

		if (!isLossy && !decodedIsLossy) {
			if ([decodedComponent isEqual:driveID]) {
				OCLog(@"decodedOCFilesystemComponentIsLossy:%@ -> %@", actualComponent, decodedComponent);
			} else {
				OCLogError(@"decodedOCFilesystemComponentIsLossy:%@ -> '%@' (actual) != '%@' (expected)", actualComponent, decodedComponent, driveID);
			}

			XCTAssert((decodedComponent != nil) && [decodedComponent isEqual:driveID]);
		}

		// Test vault location decoding
		OCVaultLocation *decodedVaultLocation = [MockVault locationForURL:actualURL];
		OCLogDebug(@"Decoded %@: driveID=%@", actualURL, decodedVaultLocation.driveID);

		XCTAssert([driveID isEqual:decodedVaultLocation.driveID]);

		// Test vault location encoding
		OCVaultLocation *vaultLocation = [OCVaultLocation new];
		vaultLocation.bookmarkUUID = bookmark.uuid;
		vaultLocation.driveID = driveID;
		vaultLocation.isVirtual = YES;

		NSURL *vaultLocationURL = [MockVault urlForLocation:vaultLocation];
		OCLogDebug(@"Encoded driveID=%@: URL=%@", driveID, vaultLocationURL);

		XCTAssert([vaultLocationURL.absoluteString isEqual:actualURLString]);
	}
}

@end
