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
#import <ownCloudSDK/OCCertificate.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCCertificateDetailsColor;
typedef NSString* OCCertificateDetailUniqueID;

typedef NS_ENUM(NSInteger, OCCertificateChangeType)
{
	OCCertificateChangeTypeNone,
	OCCertificateChangeTypeChanged,
	OCCertificateChangeTypeAdded,
	OCCertificateChangeTypeRemoved
};

@interface OCCertificateDetailsViewNode : NSObject

@property(strong,nullable) NSString *certificateKey;
@property(strong,nullable) OCCertificateDetailUniqueID uniqueKey;

@property(assign) OCCertificateChangeType changeType;

@property(strong,nullable) NSString *title;

@property(strong,nullable) NSString *value;
@property(strong,nullable) NSString *previousValue;

@property(strong,nullable) OCCertificate *certificate;
@property(strong,nullable) OCCertificate *previousCertificate;

@property(strong,nullable) UIColor *valueColor;

@property(strong,nullable) NSMutableArray *children;
 
@property(readonly,nonatomic) BOOL useFixedWidthFont;

#pragma mark - Parsing for presentation
+ (nullable NSArray <OCCertificateDetailsViewNode *> *)certificateDetailsViewNodesForCertificate:(OCCertificate *)certificate differencesFrom:(nullable OCCertificate *)previousCertificate withValidationCompletionHandler:(void(^)(NSArray <OCCertificateDetailsViewNode *> *))validationCompletionHandler;

#pragma mark - Attributed string
+ (NSAttributedString *)attributedStringWithCertificateDetails:(NSArray <OCCertificateDetailsViewNode *> *)certificateDetails colors:(nullable NSDictionary<OCCertificateDetailsColor, UIColor *> *)colors;

@end

extern OCCertificateDetailsColor OCCertificateDetailsColorSectionHeader;
extern OCCertificateDetailsColor OCCertificateDetailsColorLineTitle;
extern OCCertificateDetailsColor OCCertificateDetailsColorLineValue;

NS_ASSUME_NONNULL_END
