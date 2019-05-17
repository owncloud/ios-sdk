//
//  OCLogWriter.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 31.10.18.
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
#import "OCLogger.h"
#import "OCLogComponent.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^OCLogWriteHandler)(NSString *message);

@interface OCLogWriter : OCLogComponent
{
	BOOL _isOpen;

	OCLogWriteHandler _writeHandler;
	
	NSTimeInterval _rotationInterval;
}

@property(strong,readonly,nonatomic) NSString *name;

@property(readonly) BOOL isOpen;

@property(copy) OCLogWriteHandler writeHandler;

@property (readwrite, assign) NSTimeInterval rotationInterval;

- (instancetype)initWithWriteHandler:(OCLogWriteHandler)writeHandler;

- (nullable NSError *)open;	//!< Opens the log for writing
- (nullable NSError *)close;	//!< Closes the log

- (void)appendMessageWithLogLevel:(OCLogLevel)logLevel date:(NSDate *)date threadID:(uint64_t)threadID isMainThread:(BOOL)isMainThread privacyMasked:(BOOL)privacyMasked functionName:(NSString *)functionName file:(NSString *)file line:(NSUInteger)line tags:(nullable NSArray<OCLogTagName> *)tags message:(NSString *)message; //!< By default composes the parameters and calls -appendMessage:
- (void)appendMessage:(NSString *)message; //!< Called by the default implementation of -appendMessageWithLogLevel:functionName:file:line:message:

+ (NSString*)timestampStringFrom:(NSDate*)date;

@end

extern OCLogComponentIdentifier OCLogComponentIdentifierWriterStandardError;

NS_ASSUME_NONNULL_END
