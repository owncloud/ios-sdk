//
//  OCCertificateDetailsViewNode.h
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
#import "OCCertificate.h"

@interface OCCertificateDetailsViewNode : NSObject

@property(strong) NSString *certificateKey;

@property(strong) NSString *title;
@property(strong) NSString *value;

@property(strong) UIColor *valueColor;

@property(strong) NSMutableArray *children;

@property(readonly,nonatomic) BOOL useFixedWidthFont;

#pragma mark - Parsing for presentation
+ (NSArray <OCCertificateDetailsViewNode *> *)certificateDetailsViewNodesForCertificate:(OCCertificate *)_certificate withValidationCompletionHandler:(void(^)(NSArray <OCCertificateDetailsViewNode *> *))validationCompletionHandler;

#pragma mark - Attributed string
+ (NSAttributedString *)attributedStringWithCertificateDetails:(NSArray <OCCertificateDetailsViewNode *> *)certificateDetails;

@end
