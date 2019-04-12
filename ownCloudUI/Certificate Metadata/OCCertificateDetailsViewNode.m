//
//  OCCertificateDetailsViewNode.m
//  ownCloudUI
//
//  Created by Felix Schwarz on 13.03.18.
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

#import "OCCertificateDetailsViewNode.h"
#import "OCCertificate+OpenSSL.h"

#import <ownCloudSDK/OCMacros.h>
#import <openssl/x509v3.h>

@implementation OCCertificateDetailsViewNode

#pragma mark - Composition
+ (instancetype)nodeWithTitle:(NSString *)title value:(NSString *)value
{
	return ([self nodeWithTitle:title value:value certificateKey:nil]);
}

+ (instancetype)nodeWithTitle:(NSString *)title value:(NSString *)value certificateKey:(NSString *)certificateKey
{
	OCCertificateDetailsViewNode *node = [OCCertificateDetailsViewNode new];

	if (![value isKindOfClass:[NSString class]])
	{
		value = [value description];
	}

	node.title = title;
	node.value = value;
	node.certificateKey = certificateKey;

	return (node);
}

- (void)addNode:(OCCertificateDetailsViewNode *)node
{
	if (_children == nil) { _children = [NSMutableArray new]; }

	[_children addObject:node];
}

+ (NSSet <NSString *> *)_fixedWidthKeys
{
	static NSSet<NSString *> *fixedWidthKeys;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		fixedWidthKeys = [NSSet setWithObjects:
			// Fingerprints
			@"_fingerprint",

			// Extensions with hex data
			@SN_subject_key_identifier,
			@SN_authority_key_identifier,
			@SN_ct_precert_scts,

			// Metadata with hex data
			OCCertificateMetadataSerialNumberKey,
			OCCertificateMetadataKeyBytesKey,
		nil];
	});

	return (fixedWidthKeys);
}

- (BOOL)useFixedWidthFont
{
	return ((_certificateKey!=nil) && ([[[self class] _fixedWidthKeys] containsObject:_certificateKey]));
}

#pragma mark - Parsing for presentation
+ (NSArray <OCCertificateDetailsViewNode *> *)certificateDetailsViewNodesForCertificate:(OCCertificate *)certificate withValidationCompletionHandler:(void(^)(NSArray <OCCertificateDetailsViewNode *> *))validationCompletionHandler
{
	NSMutableArray <OCCertificateDetailsViewNode *> *sections = [NSMutableArray new];

	if (certificate != nil)
	{
		NSError *error = nil;
		NSDictionary<OCCertificateMetadataKey, id> *metaData;
		OCCertificateDetailsViewNode *validationStatusNode = nil;

		if ((metaData = [certificate metaDataWithError:&error]) != nil)
		{
			void (^AddSectionFromChildren)(NSString *title, NSArray <OCCertificateMetadataKey> *fields, NSDictionary<OCCertificateMetadataKey, id> *sectionValueDict) = ^(NSString *title, NSArray <OCCertificateMetadataKey> *fields, NSDictionary<OCCertificateMetadataKey, id> *sectionValueDict){
				OCCertificateDetailsViewNode *sectionNode = [OCCertificateDetailsViewNode nodeWithTitle:title value:nil];

				for (OCCertificateMetadataKey key in fields)
				{
					NSString *value;

					if ((value = sectionValueDict[key]) != nil)
					{
						[sectionNode addNode:[OCCertificateDetailsViewNode nodeWithTitle:OCLocalizedString(key,@"") value:value certificateKey:key]];
					}
				}

				if (sectionNode.children.count > 0)
				{
					[sections addObject:sectionNode];
				}
			};

			// Sections: Certificate
			{
				OCCertificateDetailsViewNode *certificateStatusSectionNode;

				certificateStatusSectionNode = [OCCertificateDetailsViewNode nodeWithTitle:OCLocalizedString(@"Validation Status",@"") value:nil];
				validationStatusNode = [OCCertificateDetailsViewNode nodeWithTitle:OCLocalizedString(@"Validation Status",@"") value:OCLocalizedString(@"Validating…",@"")];

				if (certificate.hostName != nil)
				{
					[certificateStatusSectionNode addNode:[OCCertificateDetailsViewNode nodeWithTitle:OCLocalizedString(@"Hostname",@"") value:certificate.hostName]];
				}

				if (validationCompletionHandler!=nil)
				{
					[certificateStatusSectionNode addNode:validationStatusNode];
				}

				[sections addObject:certificateStatusSectionNode];
			}

			// Sections: Subject & Issuer
			NSArray <OCCertificateMetadataKey> *subjectIssuerFieldsOrder = @[
				OCCertificateMetadataCommonNameKey,
				OCCertificateMetadataCountryNameKey,
				OCCertificateMetadataLocalityNameKey,
				OCCertificateMetadataStateOrProvinceNameKey,
				OCCertificateMetadataOrganizationNameKey,
				OCCertificateMetadataOrganizationUnitNameKey,
				OCCertificateMetadataJurisdictionCountryNameKey,
				OCCertificateMetadataJurisdictionLocalityNameKey,
				OCCertificateMetadataJurisdictionStateOrProvinceNameKey,
				OCCertificateMetadataBusinessCategoryKey
			];

			if (metaData[OCCertificateMetadataSubjectKey] != nil)
			{
				AddSectionFromChildren(OCLocalizedString(@"Subject",@""), subjectIssuerFieldsOrder, metaData[OCCertificateMetadataSubjectKey]);
			}

			if (metaData[OCCertificateMetadataSubjectKey] != nil)
			{
				AddSectionFromChildren(OCLocalizedString(@"Issuer",@""), subjectIssuerFieldsOrder, metaData[OCCertificateMetadataIssuerKey]);
			}

			// Section: Certificate
			AddSectionFromChildren( nil,
			  			@[OCCertificateMetadataValidFromKey,
						  OCCertificateMetadataValidUntilKey,
						  OCCertificateMetadataSignatureAlgorithmKey,
						  OCCertificateMetadataSerialNumberKey,
						  OCCertificateMetadataVersionKey],
					        metaData);

			// Section: Public Key
			AddSectionFromChildren( OCLocalizedString(@"Public Key",@""),
			  			@[OCCertificateMetadataSignatureAlgorithmKey,
						  OCCertificateMetadataKeySizeInBitsKey,
						  OCCertificateMetadataKeyExponentKey,
						  OCCertificateMetadataKeyBytesKey,
						  OCCertificateMetadataKeyInformationKey],
					        metaData[OCCertificateMetadataPublicKeyKey]);

			// Section: Extensions
			if (((NSArray *)metaData[OCCertificateMetadataExtensionsKey]).count > 0)
			{
				OCCertificateDetailsViewNode *sectionNode = [OCCertificateDetailsViewNode nodeWithTitle:OCLocalizedString(@"Extensions",@"") value:nil];

				for (NSDictionary *extensions in ((NSArray *)metaData[OCCertificateMetadataExtensionsKey]))
				{
					NSString *extensionName = extensions[OCCertificateMetadataExtensionNameKey];
					NSString *extensionValue = extensions[OCCertificateMetadataExtensionDescriptionKey];

					if ((extensionName != nil) && (extensionValue != nil))
					{
						[sectionNode addNode:[OCCertificateDetailsViewNode nodeWithTitle:extensionName value:extensionValue certificateKey:extensions[OCCertificateMetadataExtensionIdentifierKey]]];
					}
				}

				if (sectionNode.children.count > 0)
				{
					[sections addObject:sectionNode];
				}
			}

			// Section: Fingerprints
			{
				OCCertificateDetailsViewNode *sectionNode = [OCCertificateDetailsViewNode nodeWithTitle:OCLocalizedString(@"Fingerprints",@"") value:nil];

				NSString *fingerprint;

				if ((fingerprint = [[certificate sha256Fingerprint] asHexStringWithSeparator:@" "]) != nil)
				{
					[sectionNode addNode:[OCCertificateDetailsViewNode nodeWithTitle:@"SHA-256" value:fingerprint certificateKey:@"_fingerprint"]];
				}

				if ((fingerprint = [[certificate sha1Fingerprint] asHexStringWithSeparator:@" "]) != nil)
				{
					[sectionNode addNode:[OCCertificateDetailsViewNode nodeWithTitle:@"SHA-1" value:fingerprint certificateKey:@"_fingerprint"]];
				}

				if ((fingerprint = [[certificate md5Fingerprint] asHexStringWithSeparator:@" "]) != nil)
				{
					[sectionNode addNode:[OCCertificateDetailsViewNode nodeWithTitle:@"MD5" value:fingerprint certificateKey:@"_fingerprint"]];
				}

				if (sectionNode.children.count > 0)
				{
					[sections addObject:sectionNode];
				}
			}

			// Certificate
			if (certificate.parentCertificate != nil)
			{
				OCCertificateDetailsViewNode *sectionNode = [OCCertificateDetailsViewNode nodeWithTitle:OCLocalizedString(@"Certificate chain",@"") value:nil];
				NSArray <OCCertificate *> *certificateChain = [certificate chainInReverse:NO];

				[certificateChain enumerateObjectsUsingBlock:^(OCCertificate * _Nonnull certificate, NSUInteger idx, BOOL * _Nonnull stop) {
					if (idx > 0)
					{
						OCCertificateDetailsViewNode *certificateNode = [OCCertificateDetailsViewNode nodeWithTitle:((idx == certificateChain.count-1) ? OCLocalizedString(@"Root Certificate",@"") : OCLocalizedString(@"Intermediate Certificate",@"")) value:certificate.commonName certificateKey:@"_certificateChain"];

						certificateNode.certificate = certificate;

						[sectionNode addNode:certificateNode];
					}
				}];

				if (sectionNode.children.count > 0)
				{
					[sections addObject:sectionNode];
				}
			}

			// Validation
			if (validationCompletionHandler != nil)
			{
				[certificate evaluateWithCompletionHandler:^(OCCertificate *certificate, OCCertificateValidationResult validationResult, NSError *error) {
					NSString *status = @"";
					UIColor *backgroundColor = nil;

					switch (validationResult)
					{
						case OCCertificateValidationResultError:
							status = [NSString stringWithFormat:@"%@: %@", OCLocalizedString(@"Validation Error", @""), error.localizedDescription];
							backgroundColor = [UIColor redColor];
						break;

						case OCCertificateValidationResultReject:
							status = OCLocalizedString(@"User-rejected.", @"");
							backgroundColor = [UIColor redColor];
						break;

						case OCCertificateValidationResultPromptUser:
							status = OCLocalizedString(@"Certificate has issues.", @"");
							backgroundColor = [UIColor orangeColor];
						break;

						case OCCertificateValidationResultUserAccepted:
							status = OCLocalizedString(@"User-accepted.", @"");
							backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:1.0 alpha:1.0];
						break;

						case OCCertificateValidationResultPassed:
							status = OCLocalizedString(@"No issues found.", @"");
							backgroundColor = [UIColor greenColor];
						break;

						case OCCertificateValidationResultNone:
						break;
					}

					validationStatusNode.valueColor = backgroundColor;
					validationStatusNode.value = status;

					validationCompletionHandler(sections);
				}];

				validationCompletionHandler = nil;
			}
		}
	}

	if (validationCompletionHandler!=nil)
	{
		validationCompletionHandler(sections);
	}

	return (sections);
}

#pragma mark - Attributed string
+ (NSAttributedString *)attributedStringWithCertificateDetails:(NSArray <OCCertificateDetailsViewNode *> *)certificateDetails
{
	NSMutableAttributedString *attributedString = [NSMutableAttributedString new];
	NSDictionary<NSAttributedStringKey, id> *sectionTitleAttributes, *nodeTitleAttributes, *nodeValueAttributes, *nodeValueFixedAttributes;

	sectionTitleAttributes = @{
		NSFontAttributeName : [UIFont systemFontOfSize:[UIFont systemFontSize]*1.25 weight:UIFontWeightBold],
		NSForegroundColorAttributeName : [UIColor blackColor]
	};

	nodeTitleAttributes = @{
		NSFontAttributeName : [UIFont systemFontOfSize:[UIFont smallSystemFontSize] weight:UIFontWeightMedium],
		NSForegroundColorAttributeName : [UIColor grayColor]
	};

	nodeValueAttributes = @{
		NSFontAttributeName : [UIFont monospacedDigitSystemFontOfSize:[UIFont systemFontSize] weight:UIFontWeightRegular],
		NSForegroundColorAttributeName : [UIColor blackColor]
	};

	nodeValueFixedAttributes = @{
		NSFontAttributeName : [UIFont fontWithName:@"Menlo" size:[UIFont systemFontSize]],
		NSForegroundColorAttributeName : [UIColor blackColor]
	};

	for (OCCertificateDetailsViewNode *sectionNode in certificateDetails)
	{
		if (attributedString.length > 0)
		{
			[attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
		}

		if (sectionNode.title != nil)
		{
			[attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:[sectionNode.title stringByAppendingFormat:@"\n\n"] attributes:sectionTitleAttributes]];
		}

		for (OCCertificateDetailsViewNode *childNode in sectionNode.children)
		{
			if (childNode.title != nil)
			{
				[attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:[childNode.title.uppercaseString stringByAppendingFormat:@"\n"] attributes:nodeTitleAttributes]];
			}

			if (childNode.value != nil)
			{
				[attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:[childNode.value stringByAppendingFormat:@"\n\n"] attributes:(childNode.useFixedWidthFont ? nodeValueFixedAttributes : nodeValueAttributes)]];
			}
		}
	}

	return (attributedString);
}

@end
