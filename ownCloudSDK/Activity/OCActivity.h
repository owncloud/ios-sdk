//
//  OCActivity.h
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
#import "OCIssue.h"

typedef NSString* OCActivityIdentifier;

typedef NS_ENUM(NSUInteger, OCActivityState)
{
	OCActivityStatePending,	//!< Activity is pending
	OCActivityStateRunning, //!< Activity is being executed
	OCActivityStatePaused,  //!< Activity is paused
	OCActivityStateFailed	//!< Activity has failed (and optionally awaits resolution)
};

NS_ASSUME_NONNULL_BEGIN

@class OCActivity;
@class OCActivityUpdate;

@protocol OCActivitySource

@required
@property(readonly,nonatomic) OCActivityIdentifier activityIdentifier; //!< Returns an identifier uniquely identifying the source's activity.

@optional
- (OCActivity *)provideActivity; //!< Returns a new instance of OCActivity representing the source's activity.

@end

@interface OCActivity : NSObject
{
	OCActivityIdentifier _identifier;

	OCActivityState _state;

	NSInteger _ranking;

	NSString *_localizedDescription;
	NSString *_localizedStatusMessage;

	NSProgress *_progress;

	OCIssue *_issue;

	BOOL _isCancellable;
}

@property(strong) OCActivityIdentifier identifier; //!< Identifier uniquely identifying an activity

@property(assign,nonatomic) OCActivityState state; //!< State of the activity

@property(assign) NSInteger ranking; //!< Lower numbers for higher prioritized items

@property(strong) NSString *localizedDescription; //!< Localized description of the activity (f.ex. "Copying party.jpg to Photos..")
@property(nullable,strong) NSString *localizedStatusMessage; //!< Localized message describing the status of the activity (f.ex. "Waiting for response..")

@property(nullable,strong) NSProgress *progress; //!< Progress information on the activity

@property(nullable,strong) OCIssue *issue; //!< If .state is failed, an issue that can be used to resolve the failure (optional)

@property(assign) BOOL isCancellable; //!< If YES, the activity can be cancelled

+ (instancetype)withIdentifier:(OCActivityIdentifier)identifier description:(NSString *)description statusMessage:(nullable NSString *)statusMessage ranking:(NSInteger)ranking;

- (instancetype)initWithIdentifier:(OCActivityIdentifier)identifier;

- (NSError *)applyUpdate:(OCActivityUpdate *)update; //!< Applies an update to the activity. Returns nil if the update could be applied, an error otherwise.
- (NSError *)applyValue:(nullable id <NSObject>)value forKeyPath:(NSString *)keyPath; //!< Applies a new value to a keypath (entrypoint for subclassing)

- (void)cancel;

@end

NS_ASSUME_NONNULL_END
