//
//  OCKeyValueRecord.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 23.08.19.
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

NS_ASSUME_NONNULL_BEGIN

typedef NSUInteger OCKeyValueRecordSeed;

typedef NS_ENUM(NSUInteger, OCKeyValueRecordType)
{
	OCKeyValueRecordTypeValue,
	OCKeyValueRecordTypeStack
};

@interface OCKeyValueRecord : NSObject <NSSecureCoding>

@property(assign, readonly) OCKeyValueRecordSeed seed;
@property(assign, readonly) OCKeyValueRecordType type;

@property(strong, nullable, readonly) NSData *data;
@property(strong, nullable, readonly) id<NSSecureCoding> object;

- (instancetype)initWithValue:(id<NSSecureCoding>)value;

- (void)updateWithObject:(id<NSSecureCoding>)object;
- (BOOL)updateFromRecord:(OCKeyValueRecord *)otherRecord;

- (id<NSSecureCoding>)decodeObjectWithClasses:(NSSet<Class> *)decodeClasses;

@end

NS_ASSUME_NONNULL_END
