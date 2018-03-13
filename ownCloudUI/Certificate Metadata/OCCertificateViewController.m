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
	NSArray <OCCertificateDetailsViewNode *> *_sectionNodes;
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
	_certificate = certificate;

	if (_certificate != nil)
	{
		[_certificate certificateDetailsViewNodesWithValidationCompletionHandler:^(NSArray<OCCertificateDetailsViewNode *> *detailsViewNodes) {
			dispatch_async(dispatch_get_main_queue(), ^{
				_sectionNodes = detailsViewNodes;
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
	OCCertificateDetailsViewNode *node = _sectionNodes[indexPath.section].children[indexPath.row];

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:(node.useFixedWidthFont ? @"certCellMono" : @"certCell") forIndexPath:indexPath];

	((OCCertificateTableCell *)cell).titleLabel.text = node.title.uppercaseString;
	((OCCertificateTableCell *)cell).descriptionLabel.text = node.value;

	((OCCertificateTableCell *)cell).descriptionLabel.textColor = (node.valueColor != nil) ? node.valueColor : nil;

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
