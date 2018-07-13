//
//  OCRetainer.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 21.06.18.
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

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, OCRetainerType)
{
	OCRetainerTypeProcess,	//!< Retains the file temporarily. Automatically expires if the app adding the retainer has been terminated.
	OCRetainerTypeExpires,	//!< Retains the file until a certain date
	OCRetainerTypeExplicit	//!< Retains the file indefinitely until it is released again, using the same explicitIdentifier.
};

@interface OCRetainer : NSObject <NSSecureCoding>
{
	OCRetainerType _type;

	pid_t _processID;
	NSString *_processBundleIdentifier;

	NSString *_explicitIdentifier;

	NSDate *_expiryDate;
}

@property(readonly, assign) OCRetainerType type;

@property(readonly, strong) NSUUID *uuid;

@property(readonly) pid_t processID;
@property(readonly, strong) NSString *processBundleIdentifier;

@property(readonly, strong) NSString *explicitIdentifier;

@property(readonly, strong) NSDate *expiryDate;

@property(readonly, nonatomic) BOOL isValid;

+ (instancetype)processRetainer; //!< Retains the file temporarily. Automatically expires if the app adding the retainer has been terminated.
+ (instancetype)explicitRetainerWithIdentifier:(NSString *)identifier; //!< Retains the file until a certain date
+ (instancetype)expiringRetainerValidUntil:(NSDate *)expiryDate; //!< Retains the file indefinitely until it is released again, using the same explicitIdentifier.

@end
