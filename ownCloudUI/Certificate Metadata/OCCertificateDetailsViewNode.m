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
+ (nullable NSDate *)_parsedDateFromOpenSSLString:(NSString *)openSSLDateString
{
	static NSDateFormatter *dateFormatter;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		dateFormatter = [[NSDateFormatter alloc] init];

		dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
		dateFormatter.dateFormat = @"MMM dd HH':'mm':'ss yyyy 'GMT'"; // "Apr  4 03:03:00 2021 GMT"
		dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
	});

	return ([dateFormatter dateFromString:openSSLDateString]);
}

+ (nullable NSArray <OCCertificateDetailsViewNode *> *)certificateDetailsViewNodesForCertificate:(OCCertificate *)certificate differencesFrom:(nullable OCCertificate *)previousCertificate withValidationCompletionHandler:(void(^)(NSArray <OCCertificateDetailsViewNode *> *))validationCompletionHandler
{
	NSMutableArray <OCCertificateDetailsViewNode *> *sections = [NSMutableArray new];

	if (certificate != nil)
	{
		NSError *error = nil;
		NSDictionary<OCCertificateMetadataKey, id> *metaData;
		NSDictionary<OCCertificateMetadataKey, id> *previousMetaData = nil;
		OCCertificateDetailsViewNode *validationStatusNode = nil;

		if ((metaData = [certificate metaDataWithError:&error]) != nil)
		{
			if (previousCertificate != nil)
			{
				previousMetaData = [previousCertificate metaDataWithError:&error];
			}

			void (^AddSectionFromChildren)(NSString *title, NSArray <OCCertificateMetadataKey> *fields, NSDictionary<OCCertificateMetadataKey, id> *sectionValueDict, NSDictionary<OCCertificateMetadataKey, id> *previousSectionValueDict) = ^(NSString *title, NSArray <OCCertificateMetadataKey> *fields, NSDictionary<OCCertificateMetadataKey, id> *sectionValueDict, NSDictionary<OCCertificateMetadataKey, id> *previousSectionValueDict){
				OCCertificateDetailsViewNode *sectionNode = [OCCertificateDetailsViewNode nodeWithTitle:title value:nil];

				for (OCCertificateMetadataKey key in fields)
				{
					NSString *value = sectionValueDict[key];
					NSString *previousValue = previousSectionValueDict[key];

					if ([key isEqual:OCCertificateMetadataValidUntilKey])
					{
						// Check expiration date
						NSDate *validUntilDate;

						if ((value != nil) && ((validUntilDate = [OCCertificateDetailsViewNode _parsedDateFromOpenSSLString:value]) != nil) && ([validUntilDate timeIntervalSinceNow] < 0))
						{
							value = [value stringByAppendingString:@" ⚠️"];
						}

						if ((previousValue != nil) && ((validUntilDate = [OCCertificateDetailsViewNode _parsedDateFromOpenSSLString:previousValue]) != nil) && ([validUntilDate timeIntervalSinceNow] < 0))
						{
							previousValue = [previousValue stringByAppendingString:@" ⚠️"];
						}
					}

					if ((value != nil) || (previousValue != nil))
					{
						OCCertificateDetailsViewNode *node = [OCCertificateDetailsViewNode nodeWithTitle:OCLocalizedString(key,@"") value:value certificateKey:key];

						if (previousSectionValueDict != nil)
						{
							// Ensure previousValue is a string
							if (![previousValue isKindOfClass:NSString.class])
							{
								previousValue = [previousValue description];
							}

							node.previousValue = previousValue;

							if ((value != nil) && (previousValue == nil))
							{
								node.changeType = OCCertificateChangeTypeAdded;
							}

							if ((value == nil) && (previousValue != nil))
							{
								node.changeType = OCCertificateChangeTypeRemoved;
							}

							if ((value != nil) && (previousValue != nil) && ![value isEqual:previousValue])
							{
								node.changeType = OCCertificateChangeTypeChanged;
							}
						}

						[sectionNode addNode:node];
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

				if ((certificate.hostName != nil) || (previousCertificate.hostName != nil))
				{
					OCCertificateDetailsViewNode *node = [OCCertificateDetailsViewNode nodeWithTitle:OCLocalizedString(@"Hostname",@"") value:certificate.hostName];

					if (previousCertificate != nil)
					{
						node.previousValue = previousCertificate.hostName;

						if (previousCertificate.hostName == nil)
						{
							node.changeType = OCCertificateChangeTypeAdded;
						}
						else if (certificate.hostName == nil)
						{
							node.changeType = OCCertificateChangeTypeRemoved;
						}
						else if (![certificate.hostName isEqual:previousCertificate.hostName])
						{
							node.changeType = OCCertificateChangeTypeChanged;
						}
						else
						{
							node.changeType = OCCertificateChangeTypeNone;
						}
					}

					[certificateStatusSectionNode addNode:node];
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
				AddSectionFromChildren(OCLocalizedString(@"Subject",@""), subjectIssuerFieldsOrder, metaData[OCCertificateMetadataSubjectKey], previousMetaData[OCCertificateMetadataSubjectKey]);
			}

			if (metaData[OCCertificateMetadataSubjectKey] != nil)
			{
				AddSectionFromChildren(OCLocalizedString(@"Issuer",@""), subjectIssuerFieldsOrder, metaData[OCCertificateMetadataIssuerKey], previousMetaData[OCCertificateMetadataIssuerKey]);
			}

			// Section: Certificate
			AddSectionFromChildren( nil,
			  			@[OCCertificateMetadataValidFromKey,
						  OCCertificateMetadataValidUntilKey,
						  OCCertificateMetadataSignatureAlgorithmKey,
						  OCCertificateMetadataSerialNumberKey,
						  OCCertificateMetadataVersionKey],
					        metaData, previousMetaData);

			// Section: Public Key
			AddSectionFromChildren( OCLocalizedString(@"Public Key",@""),
			  			@[OCCertificateMetadataSignatureAlgorithmKey,
						  OCCertificateMetadataKeySizeInBitsKey,
						  OCCertificateMetadataKeyExponentKey,
						  OCCertificateMetadataKeyBytesKey,
						  OCCertificateMetadataKeyInformationKey],
					        metaData[OCCertificateMetadataPublicKeyKey], previousMetaData[OCCertificateMetadataPublicKeyKey]);

			// Section: Extensions
			if (((NSArray *)metaData[OCCertificateMetadataExtensionsKey]).count > 0)
			{
				OCCertificateDetailsViewNode *sectionNode = [OCCertificateDetailsViewNode nodeWithTitle:OCLocalizedString(@"Extensions",@"") value:nil];
				NSArray<NSDictionary<OCCertificateMetadataKey, NSString *> *> *extensions =  metaData[OCCertificateMetadataExtensionsKey];
				NSMutableArray<NSDictionary<OCCertificateMetadataKey, NSString *> *> *previousExtensions =  [previousMetaData[OCCertificateMetadataExtensionsKey] mutableCopy];

				for (NSDictionary<OCCertificateMetadataKey, NSString *> *extension in extensions)
				{
					NSString *extensionName = extension[OCCertificateMetadataExtensionNameKey];
					NSString *extensionValue = extension[OCCertificateMetadataExtensionDescriptionKey];

					if ((extensionName != nil) && (extensionValue != nil))
					{
						OCCertificateDetailsViewNode *node = [OCCertificateDetailsViewNode nodeWithTitle:extensionName value:extensionValue certificateKey:extension[OCCertificateMetadataExtensionIdentifierKey]];

						if (previousExtensions!=nil)
						{
							if ([previousExtensions containsObject:extension])
							{
								// Unchanged
								[previousExtensions removeObject:extension];
							}
							else
							{
								// Change found - determine which one
								NSString *extensionIdentifier = extension[OCCertificateMetadataExtensionIdentifierKey];

								NSDictionary<OCCertificateMetadataKey, NSString *> *matchingPreviousExtension = nil;
								NSUInteger matchingPreviousExtensionScore = 0;

								for (NSDictionary<OCCertificateMetadataKey, NSString *> *previousExtension in previousExtensions)
								{
									NSString *previousExtensionName = previousExtension[OCCertificateMetadataExtensionNameKey];
									NSString *previousExtensionValue = previousExtension[OCCertificateMetadataExtensionDescriptionKey];
									NSString *previousExtensionIdentifier = previousExtension[OCCertificateMetadataExtensionIdentifierKey];

									NSUInteger matchScore = 0;

									if ([extensionIdentifier isEqual:previousExtensionIdentifier])
									{
										// ID match > name match
										matchScore += 10;
									}

									if ([previousExtensionName isEqual:previousExtensionName])
									{
										// Name match
										matchScore += 5;

										if ([previousExtensionValue isEqual:previousExtensionValue])
										{
											// Exact name/value match!
											matchScore += 100;
										}
									}

									if (matchScore > matchingPreviousExtensionScore)
									{
										matchingPreviousExtensionScore = matchScore;
										matchingPreviousExtension = previousExtension;
									}
								}

								if (matchingPreviousExtension != nil)
								{
									NSString *previousExtensionValue = matchingPreviousExtension[OCCertificateMetadataExtensionDescriptionKey];

									if (![previousExtensionValue isEqual:extensionValue])
									{
										node.changeType = OCCertificateChangeTypeChanged;
										node.previousValue = previousExtensionValue;
									}

									[previousExtensions removeObject:matchingPreviousExtension];
								}
								else
								{
									node.changeType = OCCertificateChangeTypeAdded;
								}
							}
						}

						[sectionNode addNode:node];
					}
				}

				for (NSDictionary<OCCertificateMetadataKey, NSString *> *extension in previousExtensions)
				{
					NSString *previousExtensionName = extension[OCCertificateMetadataExtensionNameKey];
					NSString *previousExtensionValue = extension[OCCertificateMetadataExtensionDescriptionKey];

					if ((previousExtensionName != nil) && (previousExtensionValue != nil))
					{
						OCCertificateDetailsViewNode *node = [OCCertificateDetailsViewNode nodeWithTitle:previousExtensionName value:nil certificateKey:extension[OCCertificateMetadataExtensionIdentifierKey]];

						node.previousValue = previousExtensionValue;
						node.changeType = OCCertificateChangeTypeRemoved;
						[sectionNode addNode:node];
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
				NSString *previousFingerprint;

				#define AddFingerPrint(fingerprintMethod,title) \
					if ((fingerprint = [[certificate fingerprintMethod] asHexStringWithSeparator:@" "]) != nil) \
					{ \
						OCCertificateDetailsViewNode *node = [OCCertificateDetailsViewNode nodeWithTitle:title value:fingerprint certificateKey:@"_fingerprint"]; \
 					\
						if (previousCertificate != nil) \
						{ \
							previousFingerprint = [[previousCertificate fingerprintMethod] asHexStringWithSeparator:@" "]; \
							\
							node.previousValue = previousFingerprint; \
							node.changeType = [fingerprint isEqual:previousFingerprint] ? OCCertificateChangeTypeNone : OCCertificateChangeTypeChanged; \
						} \
						\
						[sectionNode addNode:node]; \
					}

				AddFingerPrint(sha256Fingerprint, @"SHA-256")
				AddFingerPrint(sha1Fingerprint, @"SHA-1")
				AddFingerPrint(md5Fingerprint, @"MD5")

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
				NSArray <OCCertificate *> *previousCertificateChain = [previousCertificate chainInReverse:NO];

				[certificateChain enumerateObjectsUsingBlock:^(OCCertificate * _Nonnull certificate, NSUInteger idx, BOOL * _Nonnull stop) {
					if (idx > 0)
					{
						OCCertificateDetailsViewNode *certificateNode = [OCCertificateDetailsViewNode nodeWithTitle:((idx == certificateChain.count-1) ? OCLocalizedString(@"Root Certificate",@"") : OCLocalizedString(@"Intermediate Certificate",@"")) value:certificate.commonName certificateKey:@"_certificateChain"];

						certificateNode.certificate = certificate;

						OCCertificate *previousChainCertificate = (previousCertificateChain.count > idx) ? previousCertificateChain[idx] : nil;

						if (previousCertificate != nil)
						{
							if (previousChainCertificate != nil)
							{
								if (![previousChainCertificate isEqual:certificate])
								{
									certificateNode.previousValue = previousChainCertificate.commonName;
									certificateNode.previousCertificate = previousChainCertificate;

									certificateNode.changeType = OCCertificateChangeTypeChanged;
								}
							}
							else
							{
								certificateNode.changeType = OCCertificateChangeTypeAdded;
							}
						}

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
				dispatch_group_t validationGroup = dispatch_group_create();

				dispatch_group_enter(validationGroup);

				[certificate evaluateWithCompletionHandler:^(OCCertificate *certificate, OCCertificateValidationResult validationResult, NSError *error) {
					NSString *status = @"";
					UIColor *backgroundColor = nil;

					switch (validationResult)
					{
						case OCCertificateValidationResultError:
							status = [NSString stringWithFormat:@"%@: %@", OCLocalizedString(@"Validation Error", @""), error.localizedDescription];
							backgroundColor = UIColor.systemRedColor;
						break;

						case OCCertificateValidationResultReject:
							status = OCLocalizedString(@"User-rejected.", @"");
							backgroundColor = UIColor.systemRedColor;
						break;

						case OCCertificateValidationResultPromptUser:
							status = OCLocalizedString(@"Certificate has issues.", @"");
							backgroundColor = UIColor.systemOrangeColor;
						break;

						case OCCertificateValidationResultUserAccepted:
							if ([certificate.userAcceptedReason isEqual:OCCertificateAcceptanceReasonAutoAccepted])
							{
								status = OCLocalizedString(@"Auto-accepted.", @"");
							}
							else
							{
								status = OCLocalizedString(@"User-accepted.", @"");
							}

							if (certificate.userAcceptedReasonDescription != nil)
							{
								status = [status stringByAppendingFormat:@"\n\n%@:\n%@", OCLocalizedString(@"Reason", @""), certificate.userAcceptedReasonDescription];
							}
							backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:1.0 alpha:1.0];
						break;

						case OCCertificateValidationResultPassed:
							status = OCLocalizedString(@"No issues found.", @"");
							backgroundColor = UIColor.systemGreenColor;
						break;

						case OCCertificateValidationResultNone:
						break;
					}

					validationStatusNode.valueColor = backgroundColor;
					validationStatusNode.value = status;

					dispatch_group_leave(validationGroup);
				}];

				if (previousCertificate != nil)
				{
					dispatch_group_enter(validationGroup);

					[previousCertificate evaluateWithCompletionHandler:^(OCCertificate *certificate, OCCertificateValidationResult validationResult, NSError *error) {
						dispatch_group_leave(validationGroup);
					}];
				}

				dispatch_group_notify(validationGroup, dispatch_get_main_queue(), ^{
					validationCompletionHandler(sections);
				});

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
+ (NSAttributedString *)attributedStringWithCertificateDetails:(NSArray <OCCertificateDetailsViewNode *> *)certificateDetails colors:(NSDictionary<OCCertificateDetailsColor, UIColor *> *)colors
{
	NSMutableAttributedString *attributedString = [NSMutableAttributedString new];
	NSDictionary<NSAttributedStringKey, id> *sectionTitleAttributes, *nodeTitleAttributes, *nodeValueAttributes, *nodeValueFixedAttributes;

	UIColor *sectionHeaderColor = UIColor.blackColor;
	UIColor *lineTitleColor = UIColor.grayColor;
	UIColor *lineValueColor = UIColor.blackColor;

	if (colors[OCCertificateDetailsColorSectionHeader] != nil) { sectionHeaderColor = colors[OCCertificateDetailsColorSectionHeader]; }
	if (colors[OCCertificateDetailsColorLineTitle] != nil) 	   { lineTitleColor = colors[OCCertificateDetailsColorLineTitle]; }
	if (colors[OCCertificateDetailsColorLineValue] != nil) 	   { lineValueColor = colors[OCCertificateDetailsColorLineValue]; }

	sectionTitleAttributes = @{
		NSFontAttributeName : [UIFont systemFontOfSize:[UIFont systemFontSize]*1.25 weight:UIFontWeightBold],
		NSForegroundColorAttributeName : sectionHeaderColor
	};

	nodeTitleAttributes = @{
		NSFontAttributeName : [UIFont systemFontOfSize:[UIFont smallSystemFontSize] weight:UIFontWeightMedium],
		NSForegroundColorAttributeName : lineTitleColor
	};

	nodeValueAttributes = @{
		NSFontAttributeName : [UIFont monospacedDigitSystemFontOfSize:[UIFont systemFontSize] weight:UIFontWeightRegular],
		NSForegroundColorAttributeName : lineValueColor
	};

	nodeValueFixedAttributes = @{
		NSFontAttributeName : [UIFont fontWithName:@"Menlo" size:[UIFont systemFontSize]],
		NSForegroundColorAttributeName : lineValueColor
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

OCCertificateDetailsColor OCCertificateDetailsColorSectionHeader = @"sectionHeader";
OCCertificateDetailsColor OCCertificateDetailsColorLineTitle = @"lineTitle";
OCCertificateDetailsColor OCCertificateDetailsColorLineValue = @"lineValue";
