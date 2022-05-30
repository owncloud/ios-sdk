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

typedef NSString* OCActionOptionKey NS_TYPED_ENUM;
typedef NSDictionary<OCActionOptionKey,id>* OCActionOptions;

typedef void(^OCActionBlock)(OCAction *action, OCActionOptions _Nullable options, void(^completionHandler)(NSError * _Nullable error));

@interface OCAction : NSObject <OCDataItem, OCDataItemVersion>

@property(strong) NSString *title;
@property(strong, nullable) UIImage *icon;

@property(copy, nullable) OCActionBlock actionBlock;

- (instancetype)initWithTitle:(NSString *)title icon:(nullable UIImage *)icon action:(nullable OCActionBlock)actionBlock;

- (void)runActionWithOptions:(nullable OCActionOptions)options completionHandler:(nullable void(^)(NSError * _Nullable error))completionHandler;

@end

NS_ASSUME_NONNULL_END
