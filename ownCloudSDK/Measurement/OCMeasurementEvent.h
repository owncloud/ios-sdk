//
//  OCMeasurementEvent.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 22.04.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>

typedef NSString* OCMeasurementEventIdentifier;
typedef NSTimeInterval OCMeasurementEventReference;

typedef NS_ENUM(NSInteger, OCMeasurementEventProgress)
{
	OCMeasurementEventProgressUndetermined = -1,
	OCMeasurementEventProgressStarted = 0,
	OCMeasurementEventProgressComplete = 100
};

NS_ASSUME_NONNULL_BEGIN

@interface OCMeasurementEvent : NSObject

@property(readonly) NSTimeInterval timestamp;
@property(readonly) OCMeasurementEventIdentifier identifier;
@property(readonly,nullable) NSString *message;
@property(readonly) OCMeasurementEventProgress progress;

@property(assign) OCMeasurementEventReference relatedEventReference;

+ (instancetype)eventWithIdentifier:(OCMeasurementEventIdentifier)eventIdentifier message:(nullable NSString *)message;
+ (instancetype)eventWithIdentifier:(OCMeasurementEventIdentifier)eventIdentifier message:(nullable NSString *)message progress:(OCMeasurementEventProgress)progress;
+ (instancetype)eventWithIdentifier:(OCMeasurementEventIdentifier)eventIdentifier message:(nullable NSString *)message progress:(OCMeasurementEventProgress)progress relatedEventReference:(OCMeasurementEventReference)relatedEventReference;

@end

NS_ASSUME_NONNULL_END
