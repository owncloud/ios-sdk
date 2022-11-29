//
//  OCAction.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 29.05.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <UIKit/UIKit.h>
#import "OCDataTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class OCAction;

typedef NSString* OCActionIdentifier;
typedef NSString* OCActionVersion;

typedef NSString* OCActionPropertyKey NS_TYPED_ENUM;
typedef NSDictionary<OCActionPropertyKey,id>* OCActionProperties;

typedef NSString* OCActionRunOptionKey NS_TYPED_ENUM;
typedef NSDictionary<OCActionRunOptionKey,id>* OCActionRunOptions;

typedef void(^OCActionBlock)(OCAction *action, OCActionRunOptions _Nullable options, void(^completionHandler)(NSError * _Nullable error));

typedef NS_ENUM(NSInteger, OCActionType) {
	OCActionTypeRegular,
	OCActionTypeWarning,
	OCActionTypeDestructive
} __attribute__((enum_extensibility(closed)));

@interface OCAction : NSObject <OCDataItem, OCDataItemVersioning>

@property(strong, nullable) OCActionIdentifier identifier; //!< If set, returned as .dataItemReference.
@property(strong, nullable) OCActionVersion version; //!< If set, returned as .dataItemVersion.

@property(assign) OCActionType type;

@property(strong) OCActionProperties properties;

@property(strong) NSString *title;
@property(strong, nullable) UIImage *icon;

@property(copy, nullable) OCActionBlock actionBlock;

- (instancetype)initWithTitle:(NSString *)title icon:(nullable UIImage *)icon action:(nullable OCActionBlock)actionBlock;

- (void)runActionWithOptions:(nullable OCActionRunOptions)options completionHandler:(nullable void(^)(NSError * _Nullable error))completionHandler;

@end

NS_ASSUME_NONNULL_END
