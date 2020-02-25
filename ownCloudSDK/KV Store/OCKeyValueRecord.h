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

@property(assign, readonly) OCKeyValueRecordSeed seed; //!< Seed value of the record. Changes whenever the record is updated.
@property(assign, readonly) OCKeyValueRecordType type; //!< The type of record.

@property(strong, nullable, readonly) NSData *data; //!< Data from serializing .object
@property(strong, nullable, readonly) id<NSSecureCoding> object; //!< Object from deserializing .data

- (instancetype)initWithValue:(id<NSSecureCoding>)value; //!< Creates a record of type value with the given object
- (instancetype)initWithKeyValueStack; //!< Creates a record of type stack with a new OCKeyValueStack as object

- (void)updateWithObject:(id<NSSecureCoding>)object; //!< Updates .object and .data with the provided object
- (BOOL)updateFromRecord:(OCKeyValueRecord *)otherRecord; //!< Checks otherRecord for updates and applies them. Returns YES if the record was updated from otherRecord's data, NO otherwise.

- (nullable id<NSSecureCoding>)decodeObjectWithClasses:(NSSet<Class> *)decodeClasses; //!< Decodes .data using .decodeClasses and caches the decoded object.

@end

NS_ASSUME_NONNULL_END
