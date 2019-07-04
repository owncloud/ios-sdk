//
//  OCProcessSession.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.12.18.
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

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OCProcessType)
{
	OCProcessTypeApp,
	OCProcessTypeExtension
};

@interface OCProcessSession : NSObject <NSSecureCoding>

@property(strong) NSUUID *uuid; //!< Process session UUID. This is used to distinguish between two runs of the same app.
@property(strong) NSString *bundleIdentifier; //!< Bundle identifier of the main bundle of this session. This is used to distinguish between processes.
@property(strong) NSDate *lastActive; //!< Time at which the session's process was launched and/or last updated its session data (f.ex. following a ping)
@property(strong) NSNumber *bootTimestamp; //!< Time of boot of the system this session was created on
@property(assign) OCProcessType processType; //!< Type of process (extension, app, ..)

- (instancetype)initForProcess;

#pragma mark - Serialization tools
+ (instancetype)processSessionFromSerializedData:(NSData *)serializedData;
- (nullable NSData *)serializedData;

@end

NS_ASSUME_NONNULL_END
