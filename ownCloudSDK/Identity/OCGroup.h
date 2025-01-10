//
//  OCGroup.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 01.03.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>

@class GAGroup;
@class GAIdentity;

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCGroupID;

@interface OCGroup : NSObject <NSSecureCoding, NSCopying>

@property(strong) OCGroupID identifier;

@property(nullable,strong) NSString *name;

@property(readonly,nonatomic,nullable) GAIdentity *gaIdentity;

+ (instancetype)groupWithIdentifier:(nullable OCGroupID)groupID name:(nullable NSString *)name;

+ (instancetype)groupWithGraphGroup:(GAGroup *)gaGroup;
+ (instancetype)groupWithGraphIdentity:(GAIdentity *)gaIdentity;

@end

NS_ASSUME_NONNULL_END
