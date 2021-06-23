//
//  CertificateTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 13.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>
#import <ownCloudUI/ownCloudUI.h>

@interface CertificateTests : XCTestCase

@end

@implementation CertificateTests

- (void)setUp {
	[super setUp];
	// Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
	// Put teardown code here. This method is called after the invocation of each test method in the class.
	[super tearDown];
}

- (OCCertificate *)certificateNamed:(NSString *)certName hostName:(NSString *)hostName
{
	NSURL *certURL = [[NSBundle bundleForClass:[self class]] URLForResource:certName withExtension:@"cer"];
	NSData *certData = [NSData dataWithContentsOfURL:certURL];
	OCCertificate *certificate;

	certificate = [OCCertificate certificateWithCertificateData:certData hostName:hostName];

	return (certificate);
}

- (void)testCertificateMetaDataParsing
{
	NSError *parseError;
	NSDictionary *metaData;
	XCTestExpectation *viewNodesReceivedExpectation = [self expectationWithDescription:@"expect view nodes"];

	OCCertificate *certificate = [self certificateNamed:@"fake-demo_owncloud_org" hostName:@"demo.owncloud.org"];

	XCTAssert(((metaData = [certificate metaDataWithError:&parseError]) != nil), @"Metadata returned");
	XCTAssert([((NSDictionary *)metaData[OCCertificateMetadataSubjectKey])[OCCertificateMetadataCommonNameKey] isEqual:@"demo.owncloud.org"], @"Common name is correct");

	OCLog(@"Certificate metadata: %@ Error: %@", metaData, parseError);

	[certificate certificateDetailsViewNodesComparedTo:nil withValidationCompletionHandler:^(NSArray<OCCertificateDetailsViewNode *> *nodes) {
		OCLog(@"DetailsViewNodes: %@", nodes);

		XCTAssert(nodes!=nil);
		XCTAssert(nodes.count==7);

		[viewNodesReceivedExpectation fulfill];
	}];

	[self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testCertificateMetaDataParsingFromWeb
{
	NSArray <NSURL *> *urlsToTest = @[
		[NSURL URLWithString:@"https://owncloud.org/"],
		[NSURL URLWithString:@"https://api.braintreegateway.com/"]
	];

	for (NSURL *urlToTest in urlsToTest)
	{
		OCConnection *connection = [[OCConnection alloc] initWithBookmark:[OCBookmark bookmarkForURL:urlToTest]];
		OCHTTPRequest *request = [OCHTTPRequest requestWithURL:connection.bookmark.url];

		request.forceCertificateDecisionDelegation = YES;
		request.ephermalRequestCertificateProceedHandler = ^(OCHTTPRequest *request, OCCertificate *certificate, OCCertificateValidationResult validationResult, NSError *certificateValidationError, OCConnectionCertificateProceedHandler proceedHandler) {
			NSError *parseError = nil;
			NSDictionary *metaData = [certificate metaDataWithError:&parseError];

			OCLog(@"Certificate metadata: %@ Error: %@", metaData, parseError);

			XCTAssert([((NSDictionary *)metaData[OCCertificateMetadataSubjectKey])[OCCertificateMetadataCommonNameKey] isEqual:urlToTest.host], @"Common name is host name: metaData=%@, host=%@", metaData, urlToTest.host);

			proceedHandler(YES, nil);
		};
		request.redirectPolicy = OCHTTPRequestRedirectPolicyHandleLocally;

		[connection sendSynchronousRequest:request];
	}
}

- (void)testCertificateRuleChecker
{
	OCCertificate *demoCertNew = [OCCertificate assembleChain:@[
		[self certificateNamed:@"demo-cert-root" 	hostName:nil],
		[self certificateNamed:@"demo-cert-letsencrypt" hostName:nil],
		[self certificateNamed:@"demo-cert-new" 	hostName:@"demo.owncloud.org"]
	]];

	OCCertificate *demoCertOld = [OCCertificate assembleChain:@[
		[self certificateNamed:@"demo-cert-root" 	hostName:nil],
		[self certificateNamed:@"demo-cert-letsencrypt" hostName:nil],
		[self certificateNamed:@"demo-cert-old" 	hostName:@"demo.owncloud.org"]
	]];

	OCCertificate *demoCertWrongOrder = [OCCertificate assembleChain:@[
		[self certificateNamed:@"demo-cert-letsencrypt" hostName:nil],
		[self certificateNamed:@"demo-cert-root" 	hostName:nil],
		[self certificateNamed:@"demo-cert-old" 	hostName:@"demo.owncloud.org"]
	]];

	OCCertificate *letsEncryptCertOldRoot = [OCCertificate assembleChain:@[
		[self certificateNamed:@"letsencrypt-old-root" hostName:nil],
		[self certificateNamed:@"letsencrypt-old-parent" hostName:nil],
		[self certificateNamed:@"letsencrypt-old" hostName:@"demo.owncloud.org"],
	]];

	OCCertificate *letsEncryptCertNewRoot = [OCCertificate assembleChain:@[
		[self certificateNamed:@"letsencrypt-new-root" hostName:nil],
		[self certificateNamed:@"letsencrypt-new-parent" hostName:nil],
		[self certificateNamed:@"letsencrypt-new" hostName:@"demo.owncloud.org"],
	]];

	OCLogDebug(@"demoCertNew:\n%@\n\ndemoCertOld:\n%@", demoCertNew, demoCertOld);

	BOOL (^RunCheck)(OCCertificate *certificate, OCCertificate *newCertificate, NSString *rule) = ^(OCCertificate *certificate, OCCertificate *newCertificate, NSString *rule) {
		OCCertificateRuleChecker *ruleChecker;
		BOOL ruleEvaluated;

		ruleChecker = [OCCertificateRuleChecker ruleWithCertificate:certificate newCertificate:newCertificate rule:rule];
		ruleEvaluated = ruleChecker.evaluateRule;

		OCLogDebug(@"Rule '%@': %d", ruleChecker.rule, ruleEvaluated);

		return (ruleEvaluated);
	};

	XCTAssert(RunCheck(letsEncryptCertNewRoot, nil, @"certificate.validationResult == \"passed\"") == YES);
	XCTAssert(RunCheck(demoCertOld, nil, @"certificate.validationResult == \"passed\"") == NO);

	XCTAssert(RunCheck(demoCertOld, demoCertNew, @"certificate.publicKeyData == newCertificate.publicKeyData") == NO);
	XCTAssert(RunCheck(demoCertNew, demoCertNew, @"certificate.publicKeyData == newCertificate.publicKeyData") == YES);

	XCTAssert(RunCheck(demoCertOld, demoCertNew, @"check.certificatesHaveIdenticalParents == true") == YES);
	XCTAssert(RunCheck(demoCertOld, demoCertWrongOrder, @"check.certificatesHaveIdenticalParents == true") == NO);

	XCTAssert(RunCheck(demoCertOld, demoCertNew, @"certificate == newCertificate") == NO);
	XCTAssert(RunCheck(demoCertOld, demoCertOld, @"certificate == newCertificate") == YES);

	XCTAssert(RunCheck(demoCertOld, demoCertNew, @"(certificate.publicKeyData == newCertificate.publicKeyData) OR (check.certificatesHaveIdenticalParents == true)") == YES);
	XCTAssert(RunCheck(demoCertOld, demoCertNew, @"(certificate.publicKeyData == newCertificate.publicKeyData) OR (check.parentCertificatesHaveIdenticalPublicKeys == true)") == YES);
	XCTAssert(RunCheck(demoCertOld, demoCertNew, @"(bookmarkCertificate.publicKeyData == serverCertificate.publicKeyData) OR ((check.parentCertificatesHaveIdenticalPublicKeys == true))") == YES);

	XCTAssert(RunCheck(demoCertOld, demoCertNew, @"never") == NO);
	XCTAssert(RunCheck(demoCertOld, demoCertNew, @"evaluateRule == true") == NO);
	XCTAssert(RunCheck(demoCertOld, demoCertNew, @"check.evaluateRule == true") == NO);

	NSLog(@"certificate.publicKeyData.sha256Hash.asFingerPrintString=%@", demoCertNew.publicKeyData.sha256Hash.asFingerPrintString);
	NSLog(@"certificate.commonName=%@", demoCertNew.commonName);

	XCTAssert(RunCheck(demoCertNew, nil, @"certificate.publicKeyData.sha256Hash.asFingerPrintString == \"35 69 BC 3A ED 7D B6 74 BE D8 CA 7D 4D 20 4F E8 BB 99 81 83 E1 BF 75 56 F6 B4 E8 5D 01 8A D3 42\"") == YES);
	XCTAssert(RunCheck(demoCertNew, nil, @"certificate.publicKeyData.sha256Hash.asFingerPrintString == \"AA BB CC DD EE FF 00 11 22 33 44 0A 13 34 93 5B 08 1C 89 FB 73 BD 4C 2E 67 02 3F FD DB D9 8E 79\"") == NO);

	XCTAssert(RunCheck(letsEncryptCertOldRoot, letsEncryptCertNewRoot, @"(bookmarkCertificate.parentCertificate.sha256Fingerprint.asFingerPrintString == \"73 0C 1B DC D8 5F 57 CE 5D C0 BB A7 33 E5 F1 BA 5A 92 5B 2A 77 1D 64 0A 26 F7 A4 54 22 4D AD 3B\") AND (bookmarkCertificate.rootCertificate.sha256Fingerprint.asFingerPrintString == \"06 87 26 03 31 A7 24 03 D9 09 F1 05 E6 9B CF 0D 32 E1 BD 24 93 FF C6 D9 20 6D 11 BC D6 77 07 39\") AND (serverCertificate.parentCertificate.sha256Fingerprint.asFingerPrintString == \"67 AD D1 16 6B 02 0A E6 1B 8F 5F C9 68 13 C0 4C 2A A5 89 96 07 96 86 55 72 A3 C7 E7 37 61 3D FD\") AND (serverCertificate.rootCertificate.sha256Fingerprint.asFingerPrintString == \"96 BC EC 06 26 49 76 F3 74 60 77 9A CF 28 C5 A7 CF E8 A3 C0 AA E1 1A 8F FC EE 05 C0 BD DF 08 C6\") AND (serverCertificate.passedValidationOrIsUserAccepted == true)") == YES); // Correct fingerprints

	XCTAssert(RunCheck(letsEncryptCertOldRoot, letsEncryptCertNewRoot, @"(bookmarkCertificate.parentCertificate.sha256Fingerprint.asFingerPrintString == \"73 0C 1B DC D8 5F 57 CE 5D C0 BB A7 33 E5 F1 BA 5A 92 5B 2A 77 1D 64 0A 26 F7 A4 54 22 4D AD 3B\") AND (bookmarkCertificate.rootCertificate.sha256Fingerprint.asFingerPrintString == \"06 87 26 03 31 A7 24 03 D9 09 F1 05 E6 9B CF 0D 32 E1 BD 24 93 FF C6 D9 20 6D 11 BC A6 77 07 39\") AND (serverCertificate.parentCertificate.sha256Fingerprint.asFingerPrintString == \"67 AD D1 16 6B 02 0A E6 1B 8F 5F C9 68 13 C0 4C 2A A5 89 96 07 96 86 55 72 A3 C7 E7 37 61 3D FD\") AND (serverCertificate.rootCertificate.sha256Fingerprint.asFingerPrintString == \"96 BC EC 06 26 49 76 F3 74 60 77 9A CF 28 C5 A7 CF E8 A3 C0 AA E1 1A 8F FC EE 05 C0 BD DF 08 C6\") AND (serverCertificate.passedValidationOrIsUserAccepted == true)") == NO); // Wrong fingerprint

	XCTAssert(RunCheck(letsEncryptCertNewRoot, nil, @"certificate.passedValidationOrIsUserAccepted == true") == YES);
	XCTAssert(RunCheck(demoCertNew, nil, @"certificate.commonName == \"owncloud.org\"") == YES);
	XCTAssert(RunCheck(demoCertNew, nil, @"certificate.rootCertificate.commonName == \"DST Root CA X3\"") == YES);
	XCTAssert(RunCheck(demoCertNew, nil, @"certificate.parentCertificate.commonName == \"Let's Encrypt Authority X3\"") == YES);

	XCTAssert(RunCheck(demoCertNew, nil, @"certificate.rootCertificate.commonName == \"DST Root CA X3\")") == NO); // Exception catching test
}

@end
