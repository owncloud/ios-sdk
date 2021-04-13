//
//  OCActivityUpdate.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.01.19.
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
#import "OCActivity.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger,OCActivityUpdateType)
{
	OCActivityUpdateTypePublish,
	OCActivityUpdateTypeProperty,
	OCActivityUpdateTypeUnpublish
};

@interface OCActivityUpdate : NSObject
{
	OCActivityUpdateType _type;
	OCActivityIdentifier _identifier;
	NSMutableDictionary <NSString *, id<NSObject>> *_updatesByKeyPath;
}

@property(readonly) OCActivityUpdateType type; //!< The type of activity

@property(readonly,strong) OCActivityIdentifier identifier;

@property(readonly,strong) OCActivity *activity;

@property(readonly,strong) NSDictionary <NSString *, id<NSObject>> *updatesByKeyPath;

+ (instancetype)publishingActivity:(OCActivity *)activity;
+ (instancetype)unpublishActivityForIdentifier:(OCActivityIdentifier)identifier;
+ (instancetype)updatingActivityForIdentifier:(OCActivityIdentifier)identifier;

+ (instancetype)publishingActivityFor:(id<OCActivitySource>)source;
+ (instancetype)unpublishActivityFor:(id<OCActivitySource>)source;
+ (instancetype)updatingActivityFor:(id<OCActivitySource>)source;

- (instancetype)withStatusMessage:(NSString *)statusMessage;
- (instancetype)withProgress:(nullable NSProgress *)progress;
- (instancetype)withState:(OCActivityState)state;

@end

NS_ASSUME_NONNULL_END
