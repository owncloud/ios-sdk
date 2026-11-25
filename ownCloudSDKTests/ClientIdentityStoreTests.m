//
//  ClientIdentityStoreTests.m
//  ownCloudSDKTests
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

// client-identity.p12: self-signed test identity "ownCloud SDK Test Client", password "test-password"
static NSString *sTestIdentityPassword = @"test-password";
static NSString *sTestHost = @"mtls.example.org";

@interface ClientIdentityStoreTests : XCTestCase
@end

@implementation ClientIdentityStoreTests

- (NSData *)testIdentityData
{
	NSURL *url = [[NSBundle bundleForClass:[self class]] URLForResource:@"client-identity" withExtension:@"p12"];
	XCTAssertNotNil(url);

	return ([NSData dataWithContentsOfURL:url]);
}

- (NSURLAuthenticationChallenge *)challengeForHost:(NSString *)host method:(NSString *)authenticationMethod
{
	NSURLProtectionSpace *protectionSpace = [[NSURLProtectionSpace alloc] initWithHost:host port:443 protocol:NSURLProtectionSpaceHTTPS realm:nil authenticationMethod:authenticationMethod];

	return ([[NSURLAuthenticationChallenge alloc] initWithProtectionSpace:protectionSpace proposedCredential:nil previousFailureCount:0 failureResponse:nil error:nil sender:(id<NSURLAuthenticationChallengeSender>)self]);
}

- (void)setUp
{
	[OCClientIdentityStore.sharedStore removeIdentityForHost:sTestHost];
}

- (void)tearDown
{
	[OCClientIdentityStore.sharedStore removeIdentityForHost:sTestHost];
}

- (void)testHostNormalization
{
	XCTAssertEqualObjects([OCClientIdentityStore normalizedHost:@" MTLS.Example.org. "], sTestHost);
	XCTAssertNil([OCClientIdentityStore normalizedHost:@""]);
	XCTAssertNil([OCClientIdentityStore normalizedHost:nil]);
}

- (void)testImportLookupAndRemove
{
	OCClientIdentityStore *store = OCClientIdentityStore.sharedStore;
	NSError *error = nil;

	XCTAssertFalse([store hasIdentityForHost:sTestHost]);
	XCTAssertNil([store credentialForHost:sTestHost]);

	// Import
	OCClientIdentityInfo *info = [store importPKCS12Data:[self testIdentityData] password:sTestIdentityPassword forHost:@"MTLS.example.org" error:&error];

	XCTAssertNil(error);
	XCTAssertNotNil(info);
	XCTAssertEqualObjects(info.host, sTestHost);
	XCTAssertEqualObjects(info.subjectSummary, @"ownCloud SDK Test Client");
	XCTAssertFalse(info.isExpired);

	if (@available(iOS 18, macOS 15, *))
	{
		XCTAssertNotNil(info.expiryDate);
	}

	// Lookup
	XCTAssertTrue([store hasIdentityForHost:sTestHost]);
	XCTAssertTrue([store.hosts containsObject:sTestHost]);
	XCTAssertNotNil([store credentialForHost:sTestHost].identity);
	XCTAssertEqualObjects([store identityInfoForHost:sTestHost].subjectSummary, @"ownCloud SDK Test Client");

	// Only presented to the host it was imported for, and only for client certificate challenges
	XCTAssertNil([store credentialForHost:@"other.example.org"]);
	XCTAssertNil([store credentialForHost:@"sub.mtls.example.org"]);
	XCTAssertNotNil([store credentialForChallenge:[self challengeForHost:sTestHost method:NSURLAuthenticationMethodClientCertificate]].identity);
	XCTAssertNil([store credentialForChallenge:[self challengeForHost:@"other.example.org" method:NSURLAuthenticationMethodClientCertificate]]);
	XCTAssertNil([store credentialForChallenge:[self challengeForHost:sTestHost method:NSURLAuthenticationMethodServerTrust]]);

	// Remove
	[store removeIdentityForHost:sTestHost];

	XCTAssertFalse([store hasIdentityForHost:sTestHost]);
	XCTAssertNil([store credentialForHost:sTestHost]);
	XCTAssertNil([store identityInfoForHost:sTestHost]);
	XCTAssertFalse([store.hosts containsObject:sTestHost]);
}

- (void)testWrongPasswordKeepsPreviousIdentity
{
	OCClientIdentityStore *store = OCClientIdentityStore.sharedStore;
	NSError *error = nil;

	XCTAssertNotNil([store importPKCS12Data:[self testIdentityData] password:sTestIdentityPassword forHost:sTestHost error:&error]);
	XCTAssertNil(error);

	XCTAssertNil([store importPKCS12Data:[self testIdentityData] password:@"wrong" forHost:sTestHost error:&error]);
	XCTAssertEqualObjects(error.domain, OCClientIdentityErrorDomain);
	XCTAssertEqual(error.code, OCClientIdentityErrorWrongPassword);

	XCTAssertNotNil([store credentialForHost:sTestHost], @"A failed import must not remove the stored identity");
}

- (void)testInvalidInput
{
	OCClientIdentityStore *store = OCClientIdentityStore.sharedStore;
	NSError *error = nil;

	XCTAssertNil([store importPKCS12Data:[@"not a pkcs12 file" dataUsingEncoding:NSUTF8StringEncoding] password:sTestIdentityPassword forHost:sTestHost error:&error]);
	XCTAssertEqualObjects(error.domain, OCClientIdentityErrorDomain);
	XCTAssertEqual(error.code, OCClientIdentityErrorInvalidFile);

	error = nil;
	XCTAssertNil([store importPKCS12Data:[self testIdentityData] password:sTestIdentityPassword forHost:@"  " error:&error]);
	XCTAssertEqual(error.code, OCClientIdentityErrorInvalidHost);

	XCTAssertFalse([store hasIdentityForHost:sTestHost]);
}

@end
