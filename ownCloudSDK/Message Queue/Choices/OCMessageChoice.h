//
//  OCMessageChoice.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 14.06.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCIssueChoice.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCMessageChoiceIdentifier NS_TYPED_ENUM;
typedef NSDictionary<NSString*,id<NSSecureCoding>>* OCMessageChoiceMetaData;

@interface OCMessageChoice : NSObject <NSSecureCoding>

@property(assign) OCIssueChoiceType type;

@property(strong) OCMessageChoiceIdentifier identifier;
@property(strong) NSString *label;

@property(nullable,strong) OCMessageChoiceMetaData metaData;

+ (instancetype)choiceOfType:(OCIssueChoiceType)type identifier:(OCMessageChoiceIdentifier)identifier label:(NSString *)label metaData:(nullable OCMessageChoiceMetaData)metaData;

@end

extern OCMessageChoiceIdentifier OCMessageChoiceIdentifierOK;
extern OCMessageChoiceIdentifier OCMessageChoiceIdentifierRetry;
extern OCMessageChoiceIdentifier OCMessageChoiceIdentifierCancel;

NS_ASSUME_NONNULL_END
