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
#import "OCCertificateDetailsViewNode.h"
#import "OCCertificate+OpenSSL.h"

#import <ownCloudSDK/OCMacros.h>

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
	NSArray <OCCertificateDetailsViewNode *> *_sectionNodes;
	UIFont *_regularFont;
}

@end

@implementation OCCertificateViewController

@synthesize certificate = _certificate;

@synthesize sectionHeaderTextColor = _sectionHeaderTextColor;
@synthesize lineTitleColor = _lineTitleColor;
@synthesize lineValueColor = _lineValueColor;

- (instancetype)initWithCertificate:(OCCertificate *)certificate compareCertificate:(nullable OCCertificate *)compareCertificate
{
	if ((self = [self initWithStyle:UITableViewStyleGrouped]) != nil)
	{
		self.certificate = certificate;
		self.compareCertificate = compareCertificate;
	}

	return (self);
}

- (void)viewDidLoad
{
	[super viewDidLoad];

	[self.tableView registerClass:[OCCertificateTableCell class] forCellReuseIdentifier:@"certCell"];
	[self.tableView registerClass:[OCCertificateTableCell class] forCellReuseIdentifier:@"certCellMono"];

	self.tableView.rowHeight = UITableViewAutomaticDimension;
	self.tableView.estimatedRowHeight = 100;
	self.tableView.sectionFooterHeight = 1;

	_sectionHeaderTextColor = [UIColor blackColor];
	_lineTitleColor = [UIColor grayColor];
	_lineValueColor = [UIColor blackColor];

	_regularFont = [UIFont monospacedDigitSystemFontOfSize:[UIFont systemFontSize] weight:UIFontWeightRegular];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

	if (self.presentingViewController != nil)
	{
		if (self.navigationController.viewControllers.firstObject == self)
		{
			UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(_done:)];

			if (self.compareCertificate != nil)
			{
				self.navigationItem.leftBarButtonItem = doneItem;
			}
			else
			{
				self.navigationItem.rightBarButtonItem = doneItem;
			}
		}
	}

	if ((self.compareCertificate != nil) && ![self.compareCertificate isEqual:self.certificate])
	{
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:OCLocalizedString(@"Show ±", nil) style:UIBarButtonItemStylePlain target:self action:@selector(toggleShowDifferences:)];
		[self _updateDiffLabel];
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
	_certificate = certificate;

	if (_certificate != nil)
	{
		[_certificate certificateDetailsViewNodesComparedTo:(self.showDifferences ? self.compareCertificate : nil) withValidationCompletionHandler:^(NSArray<OCCertificateDetailsViewNode *> *detailsViewNodes) {
			dispatch_async(dispatch_get_main_queue(), ^{
				self->_sectionNodes = detailsViewNodes;
				[self.tableView reloadData];
			});
		}];
	}
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
	NSMutableAttributedString *attributedText = nil;
	OCCertificateDetailsViewNode *node = _sectionNodes[indexPath.section].children[indexPath.row];
	OCCertificateTableCell *cell = (OCCertificateTableCell *)[tableView dequeueReusableCellWithIdentifier:(node.useFixedWidthFont ? @"certCellMono" : @"certCell") forIndexPath:indexPath];

	cell.titleLabel.text = node.title.uppercaseString;

	UIColor *descriptionColor = (node.valueColor != nil) ? node.valueColor : _lineValueColor;

	switch (node.changeType)
	{
		case OCCertificateChangeTypeNone:
			cell.descriptionLabel.attributedText = nil;
			cell.descriptionLabel.text = node.value;
		break;

		case OCCertificateChangeTypeChanged:
			attributedText = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"⊕ %@\n⊖ %@", node.value, node.previousValue]];
			[attributedText setAttributes:@{ NSForegroundColorAttributeName : descriptionColor, NSFontAttributeName : _regularFont  } range:NSMakeRange(0, 2)];
			[attributedText setAttributes:@{ NSForegroundColorAttributeName : UIColor.systemGreenColor } range:NSMakeRange(2, node.value.length)];

			[attributedText setAttributes:@{ NSForegroundColorAttributeName : descriptionColor, NSFontAttributeName : _regularFont  } range:NSMakeRange(attributedText.length-node.previousValue.length-2, 2)];
			[attributedText setAttributes:@{ NSForegroundColorAttributeName : UIColor.systemRedColor } range:NSMakeRange(attributedText.length-node.previousValue.length, node.previousValue.length)];
		break;

		case OCCertificateChangeTypeAdded:
			attributedText = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"⊕ %@", node.value]];
			[attributedText setAttributes:@{ NSForegroundColorAttributeName : descriptionColor, NSFontAttributeName : _regularFont  } range:NSMakeRange(0, 2)];
			[attributedText setAttributes:@{ NSForegroundColorAttributeName : UIColor.systemGreenColor } range:NSMakeRange(2, node.value.length)];
		break;

		case OCCertificateChangeTypeRemoved:
			attributedText = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"⊖ %@", node.previousValue]];
			[attributedText setAttributes:@{ NSForegroundColorAttributeName : descriptionColor, NSFontAttributeName : _regularFont } range:NSMakeRange(0, 2)];
			[attributedText setAttributes:@{ NSForegroundColorAttributeName : UIColor.systemRedColor } range:NSMakeRange(2, node.previousValue.length)];
		break;
	}

	cell.titleLabel.textColor = _lineTitleColor;

	if (attributedText != nil)
	{
		cell.descriptionLabel.text = nil;
		cell.descriptionLabel.attributedText = attributedText;
	}
	else
	{
		cell.descriptionLabel.textColor = descriptionColor;
	}

	if (node.certificate != nil)
	{
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	else
	{
		cell.accessoryType = UITableViewCellAccessoryNone;
	}

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
		sectionHeaderLabel.textColor = self.sectionHeaderTextColor;
		sectionHeaderLabel.font = [UIFont systemFontOfSize:[UIFont systemFontSize]*1.25 weight:UIFontWeightBold];

		[headerView addSubview:sectionHeaderLabel];

		[sectionHeaderLabel.leftAnchor constraintEqualToAnchor:headerView.safeAreaLayoutGuide.leftAnchor constant:18].active = YES;
		[sectionHeaderLabel.rightAnchor constraintEqualToAnchor:headerView.safeAreaLayoutGuide.rightAnchor constant:-10].active = YES;
		[sectionHeaderLabel.topAnchor constraintEqualToAnchor:headerView.topAnchor constant:20].active = YES;
		[sectionHeaderLabel.bottomAnchor constraintEqualToAnchor:headerView.bottomAnchor constant:-3].active = YES;

		[sectionHeaderLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];

		sectionHeaderLabel.text = _sectionNodes[section].title;
	}

	return (headerView);
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
	OCCertificateDetailsViewNode *node = _sectionNodes[indexPath.section].children[indexPath.row];

	if (node.certificate != nil)
	{
		return (YES);
	}

	return (NO);
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	OCCertificateDetailsViewNode *node = _sectionNodes[indexPath.section].children[indexPath.row];

	if (node.certificate != nil)
	{
		return (indexPath);
	}

	return (nil);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	OCCertificateDetailsViewNode *node = _sectionNodes[indexPath.section].children[indexPath.row];

	if (node.certificate != nil)
	{
		OCCertificateViewController *viewController = [[[self class] alloc] initWithCertificate:node.certificate compareCertificate:node.previousCertificate];

		viewController.showDifferences = self.showDifferences;

		[self.navigationController pushViewController:viewController animated:YES];
	}
}

#pragma mark - Color support
-(void)setSectionHeaderTextColor:(UIColor *)sectionHeaderTextColor
{
	_sectionHeaderTextColor = sectionHeaderTextColor;
	[self.tableView reloadData];
}

- (void)setLineTitleColor:(UIColor *)lineTitleColor
{
	_lineTitleColor = lineTitleColor;
	[self.tableView reloadData];
}

- (void)setLineValueColor:(UIColor *)lineValueColor
{
	_lineValueColor = lineValueColor;
	[self.tableView reloadData];
}

#pragma mark - Differences
- (void)setShowDifferences:(BOOL)showDifferences
{
	_showDifferences = showDifferences;

	if (_showDifferences && (_compareCertificate != nil))
	{
		[_certificate certificateDetailsViewNodesComparedTo:_compareCertificate withValidationCompletionHandler:^(NSArray<OCCertificateDetailsViewNode *> *detailsViewNodes) {
			dispatch_async(dispatch_get_main_queue(), ^{
				self->_sectionNodes = detailsViewNodes;
				[self.tableView reloadData];
			});
		}];
	}
	else
	{
		[_certificate certificateDetailsViewNodesComparedTo:(self.showDifferences ? self.compareCertificate : nil) withValidationCompletionHandler:^(NSArray<OCCertificateDetailsViewNode *> *detailsViewNodes) {
			dispatch_async(dispatch_get_main_queue(), ^{
				self->_sectionNodes = detailsViewNodes;
				[self.tableView reloadData];
			});
		}];
	}
}

- (void)toggleShowDifferences:(id)sender
{
	self.showDifferences = !self.showDifferences;

	[self _updateDiffLabel];
}

- (void)_updateDiffLabel
{
	if (_showDifferences)
	{
		self.navigationItem.rightBarButtonItem.title = OCLocalizedString(@"Hide ±", nil);
	}
	else
	{
		self.navigationItem.rightBarButtonItem.title = OCLocalizedString(@"Show ±", nil);
	}
}

@end
