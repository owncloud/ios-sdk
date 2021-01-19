//
//  OCCertificateViewController.h
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

#import <UIKit/UIKit.h>
#import <ownCloudSDK/OCCertificate.h>

NS_ASSUME_NONNULL_BEGIN

@interface OCCertificateViewController : UITableViewController
{
	OCCertificate *_certificate;

	UIColor *_sectionHeaderTextColor;
	UIColor *_lineTitleColor;
	UIColor *_lineValueColor;
}

@property(strong,nonatomic) OCCertificate *certificate; //!< The certificate to parse and present to the user
@property(strong,nonatomic,nullable) OCCertificate *compareCertificate; //!< The certificate to compare against

@property(strong,nonatomic) UIColor *sectionHeaderTextColor;
@property(strong,nonatomic) UIColor *lineTitleColor;
@property(strong,nonatomic) UIColor *lineValueColor;

@property(assign,nonatomic) BOOL showDifferences; //!< Show/hide differences between the certificates

- (instancetype)initWithCertificate:(OCCertificate *)certificate compareCertificate:(nullable OCCertificate *)compareCertificate;

@end

NS_ASSUME_NONNULL_END
