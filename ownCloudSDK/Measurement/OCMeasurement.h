//
//  OCMeasurement.h
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
#import "OCClassSettings.h"
#import "OCMeasurementEvent.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OCMeasurementState)
{
	OCMeasurementStateInitialized,
	OCMeasurementStateStarted,
	OCMeasurementStateTerminated
};

typedef NSString* OCMeasurementIdentifier;

@class OCMeasurement;

@protocol OCMeasurementHost <NSObject>
- (nullable OCMeasurement *)hostedMeasurement;
@end

@interface OCMeasurement : NSObject <OCClassSettingsSupport, OCLogTagging>

@property(strong,readonly) OCMeasurementIdentifier identifier;

@property(assign) OCMeasurementState state;
@property(strong,nullable) NSString *title;

@property(readonly) NSTimeInterval startTimeSinceReferenceDate;
@property(readonly) NSTimeInterval endTimeSinceReferenceDate;

@property(assign) BOOL autoSummarize;

+ (nullable instancetype)measurementWithTitle:(nullable NSString *)title;

- (OCMeasurementEventReference)emitEvent:(OCMeasurementEvent *)event;

- (void)start;
- (void)terminate;
- (void)logIfNeeded:(BOOL)ifNeeded;

@end

@interface NSObject (MeasurementExtractor)
- (nullable OCMeasurement *)extractedMeasurement;
- (void)attachMeasurement:(nullable OCMeasurement *)measurement;
- (void)detachMeasurement:(nullable OCMeasurement *)measurement;
@end

#define OCMeasureEventBegin(host,eventID,storeEventRef,Message) OCMeasurementEventReference storeEventRef = [[host extractedMeasurement] emitEvent:[OCMeasurementEvent eventWithIdentifier:eventID message:(Message) progress:OCMeasurementEventProgressStarted]]
#define OCMeasureEventEnd(host,eventID,relatedEventRef,Message) [[host extractedMeasurement] emitEvent:[OCMeasurementEvent eventWithIdentifier:eventID message:(Message) progress:OCMeasurementEventProgressComplete relatedEventReference:relatedEventRef]]

#define OCMeasureEvent(host,eventID,Message) [[host extractedMeasurement] emitEvent:[OCMeasurementEvent eventWithIdentifier:eventID message:(Message)]]
#define OCMeasureEventProgress(host,eventID,Message,Progress) [[host extractedMeasurement] emitEvent:[OCMeasurementEvent eventWithIdentifier:eventID message:(Message) progress:Progress]]
#define OCMeasureStart(host) [[host extractedMeasurement] start]
#define OCMeasureTerminate(host) [[host extractedMeasurement] terminate]
#define OCMeasureLog(host) [[host extractedMeasurement] logIfNeeded:YES]

extern OCClassSettingsIdentifier OCClassSettingsIdentifierMeasurements;
extern OCClassSettingsKey OCClassSettingsKeyMeasurementsEnabled;

NS_ASSUME_NONNULL_END
