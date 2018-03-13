//
//  OCCertificateViewController.m
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

#import "OCCertificateViewController.h"
#import <ownCloudSDK/OCMacros.h>

#import <openssl/x509v3.h>

#pragma mark - Nodes
@interface OCCertificateViewNode : NSObject

@property(strong) NSString *certificateKey;

@property(strong) NSString *title;
@property(strong) NSString *value;

@property(strong) NSMutableArray *children;

@property(strong) UIColor *valueColor;

@end

@implementation OCCertificateViewNode

+ (instancetype)nodeWithTitle:(NSString *)title value:(NSString *)value
{
	return ([self nodeWithTitle:title value:value certificateKey:nil]);
}

+ (instancetype)nodeWithTitle:(NSString *)title value:(NSString *)value certificateKey:(NSString *)certificateKey
{
	OCCertificateViewNode *node = [OCCertificateViewNode new];

	if (![value isKindOfClass:[NSString class]])
	{
		value = [value description];
	}

	node.title = title;
	node.value = value;
	node.certificateKey = certificateKey;

	return (node);
}

- (void)addNode:(OCCertificateViewNode *)node
{
	if (_children == nil) { _children = [NSMutableArray new]; }

	[_children addObject:node];
}

@end

#pragma mark - Table Cells
@interface OCCertificateTableCell : UITableViewCell
{
	UILabel *_titleLabel;
	UILabel *_descriptionLabel;
}

@property(strong) UILabel *titleLabel;
@property(strong) UILabel *descriptionLabel;

@end

@implementation OCCertificateTableCell

@synthesize titleLabel = _titleLabel;
@synthesize descriptionLabel = _descriptionLabel;

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) != nil)
	{
		UIView *contentView = self.contentView;

		_titleLabel = [UILabel new];
		_titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
		_titleLabel.textColor = [UIColor grayColor];
		_titleLabel.font = [UIFont systemFontOfSize:[UIFont smallSystemFontSize] weight:UIFontWeightMedium];
		[contentView addSubview:_titleLabel];

		_descriptionLabel = [UILabel new];
		_descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
		_descriptionLabel.numberOfLines = 0;
		if ([reuseIdentifier isEqualToString:@"certCellMono"])
		{
			_descriptionLabel.font = [UIFont fontWithName:@"Menlo" size:[UIFont systemFontSize]];
		}
		else
		{
			_descriptionLabel.font = [UIFont monospacedDigitSystemFontOfSize:[UIFont systemFontSize] weight:UIFontWeightRegular];
		}
		[contentView addSubview:_descriptionLabel];

		[_titleLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:18].active = YES;
		[_titleLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-10].active = YES;
		[_titleLabel.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:7].active = YES;

		[_descriptionLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:18].active = YES;
		[_descriptionLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-10].active = YES;
		[_descriptionLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:5].active = YES;
		[_descriptionLabel.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-7].active = YES;

		[_titleLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
		[_titleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];

		[_descriptionLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
		[_descriptionLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
	}

	return (self);
}

@end

#pragma mark - Certificate view controller
@interface OCCertificateViewController ()
{
	NSMutableArray <OCCertificateViewNode *> *_sectionNodes;
	NSArray<OCCertificateMetadataKey> *_fixedWidthKeys;
}

@end

@implementation OCCertificateViewController

@synthesize certificate = _certificate;

- (instancetype)initWithCertificate:(OCCertificate *)certificate
{
	if ((self = [self initWithStyle:UITableViewStyleGrouped]) != nil)
	{
		self.certificate = certificate;
	}

	return (self);
}

- (void)viewDidLoad
{
	[super viewDidLoad];

	_fixedWidthKeys = @[
		// Fingerprints
		@"_fingerprint",

		// Extensions with hex data
		@SN_subject_key_identifier,
		@SN_authority_key_identifier,
		@SN_ct_precert_scts,

		// Metadata with hex data
		OCCertificateMetadataSerialNumberKey,
		OCCertificateMetadataKeyBytesKey,
	];

	[self.tableView registerClass:[OCCertificateTableCell class] forCellReuseIdentifier:@"certCell"];
	[self.tableView registerClass:[OCCertificateTableCell class] forCellReuseIdentifier:@"certCellMono"];

	self.tableView.rowHeight = UITableViewAutomaticDimension;
	self.tableView.estimatedRowHeight = 100;
	self.tableView.sectionFooterHeight = 1;
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

	if (self.presentingViewController != nil)
	{
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(_done:)];
	}

	self.navigationItem.title = OCLocalizedString(@"Certificate Details", @"");
}

- (void)_done:(id)sender
{
	if (self.presentingViewController != nil)
	{
		[self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
	}
}

- (void)setCertificate:(OCCertificate *)certificate
{
	NSMutableArray <OCCertificateViewNode *> *sections = [NSMutableArray new];

	_certificate = certificate;

	if (_certificate != nil)
	{
		NSError *error = nil;
		NSDictionary<OCCertificateMetadataKey, id> *metaData;

		if ((metaData = [certificate metaDataWithError:&error]) != nil)
		{
			void (^AddSectionFromChildren)(NSString *title, NSArray <OCCertificateMetadataKey> *fields, NSDictionary<OCCertificateMetadataKey, id> *sectionValueDict) = ^(NSString *title, NSArray <OCCertificateMetadataKey> *fields, NSDictionary<OCCertificateMetadataKey, id> *sectionValueDict){
				OCCertificateViewNode *sectionNode = [OCCertificateViewNode nodeWithTitle:title value:nil];

				for (OCCertificateMetadataKey key in fields)
				{
					NSString *value;

					if ((value = sectionValueDict[key]) != nil)
					{
						[sectionNode addNode:[OCCertificateViewNode nodeWithTitle:OCLocalizedString(key,@"") value:value certificateKey:key]];
					}
				}

				if (sectionNode.children.count > 0)
				{
					[sections addObject:sectionNode];
				}
			};

			// Sections: Certificate
			{
				OCCertificateViewNode *certificateStatusSectionNode = [OCCertificateViewNode nodeWithTitle:OCLocalizedString(@"Validation Status",@"") value:nil];

				[certificateStatusSectionNode addNode:[OCCertificateViewNode nodeWithTitle:OCLocalizedString(@"Hostname",@"") value:_certificate.hostName]];

				[_certificate evaluateWithCompletionHandler:^(OCCertificate *certificate, OCCertificateValidationResult validationResult, NSError *error) {
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
							backgroundColor = [UIColor blueColor];
						break;

						case OCCertificateValidationResultPassed:
							status = OCLocalizedString(@"No issues found.", @"");
							backgroundColor = [UIColor greenColor];
						break;

						case OCCertificateValidationResultNone:
						break;
					}

					OCCertificateViewNode *node = [OCCertificateViewNode nodeWithTitle:OCLocalizedString(@"Validation Status",@"") value:status];

					node.valueColor = backgroundColor;

					[certificateStatusSectionNode addNode:node];

					dispatch_async(dispatch_get_main_queue(), ^{
						[self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
					});
				}];

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
				OCCertificateViewNode *sectionNode = [OCCertificateViewNode nodeWithTitle:OCLocalizedString(@"Extensions",@"") value:nil];

				for (NSDictionary *extensions in ((NSArray *)metaData[OCCertificateMetadataExtensionsKey]))
				{
					NSString *extensionName = extensions[OCCertificateMetadataExtensionNameKey];
					NSString *extensionValue = extensions[OCCertificateMetadataExtensionDescriptionKey];

					if ((extensionName != nil) && (extensionValue != nil))
					{
						[sectionNode addNode:[OCCertificateViewNode nodeWithTitle:extensionName value:extensionValue certificateKey:extensions[OCCertificateMetadataExtensionIdentifierKey]]];
					}
				}

				if (sectionNode.children.count > 0)
				{
					[sections addObject:sectionNode];
				}
			}

			// Section: Fingerprints
			{
				OCCertificateViewNode *sectionNode = [OCCertificateViewNode nodeWithTitle:OCLocalizedString(@"Fingerprints",@"") value:nil];

				NSString *fingerprint;

				if ((fingerprint = [[_certificate sha256Fingerprint] asHexStringWithSeparator:@" "]) != nil)
				{
					[sectionNode addNode:[OCCertificateViewNode nodeWithTitle:@"SHA-256" value:fingerprint certificateKey:@"_fingerprint"]];
				}

				if ((fingerprint = [[_certificate sha1Fingerprint] asHexStringWithSeparator:@" "]) != nil)
				{
					[sectionNode addNode:[OCCertificateViewNode nodeWithTitle:@"SHA-1" value:fingerprint certificateKey:@"_fingerprint"]];
				}

				if ((fingerprint = [[_certificate md5Fingerprint] asHexStringWithSeparator:@" "]) != nil)
				{
					[sectionNode addNode:[OCCertificateViewNode nodeWithTitle:@"MD5" value:fingerprint certificateKey:@"_fingerprint"]];
				}

				if (sectionNode.children.count > 0)
				{
					[sections addObject:sectionNode];
				}
			}
		}
	}

	_sectionNodes = sections;
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return (_sectionNodes.count);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return (_sectionNodes[section].children.count);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	OCCertificateViewNode *node = _sectionNodes[indexPath.section].children[indexPath.row];

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:(((node.certificateKey!=nil) && [_fixedWidthKeys containsObject:node.certificateKey]) ? @"certCellMono" : @"certCell") forIndexPath:indexPath];

	((OCCertificateTableCell *)cell).titleLabel.text = node.title.uppercaseString;
	((OCCertificateTableCell *)cell).descriptionLabel.text = node.value;

	((OCCertificateTableCell *)cell).descriptionLabel.textColor = (node.valueColor != nil) ? node.valueColor : nil;

	// ((OCCertificateTableCell *)cell).backgroundColor = (node.backgroundColor != nil) ? node.backgroundColor : [UIColor whiteColor];

	return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	UILabel *sectionHeaderLabel = nil;
	UIView *headerView = nil;

	if (_sectionNodes[section].title != nil)
	{
		headerView = [UIView new];
		[headerView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
		[headerView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];

		sectionHeaderLabel = [UILabel new];
		sectionHeaderLabel.translatesAutoresizingMaskIntoConstraints = NO;
		sectionHeaderLabel.textColor = [UIColor blackColor];
		sectionHeaderLabel.font = [UIFont systemFontOfSize:[UIFont systemFontSize]*1.25 weight:UIFontWeightBold];

		[headerView addSubview:sectionHeaderLabel];

		[sectionHeaderLabel.leftAnchor constraintEqualToAnchor:headerView.leftAnchor constant:18].active = YES;
		[sectionHeaderLabel.rightAnchor constraintEqualToAnchor:headerView.rightAnchor constant:-10].active = YES;
		[sectionHeaderLabel.topAnchor constraintEqualToAnchor:headerView.topAnchor constant:20].active = YES;
		[sectionHeaderLabel.bottomAnchor constraintEqualToAnchor:headerView.bottomAnchor constant:-3].active = YES;

		[sectionHeaderLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];

		sectionHeaderLabel.text = _sectionNodes[section].title;
	}

	return (headerView);
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
	return (NO);
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	return (nil);
}

@end
