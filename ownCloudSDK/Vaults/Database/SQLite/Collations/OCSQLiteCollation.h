//
//  OCSQLiteCollation.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 22.11.21.
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
#import <sqlite3.h>

NS_ASSUME_NONNULL_BEGIN

@class OCSQLiteDB;

typedef NSString* OCSQLiteCollationName;

typedef NS_ENUM(int, OCSQLiteTextRepresentation) {
	OCSQLiteTextRepresentationUTF8 = SQLITE_UTF8,
	OCSQLiteTextRepresentationUTF16LE = SQLITE_UTF16LE,
	OCSQLiteTextRepresentationUTF16BE = SQLITE_UTF16BE,
	OCSQLiteTextRepresentationUTF16 = SQLITE_UTF16,
	OCSQLiteTextRepresentationUTF16Aligned = SQLITE_UTF16_ALIGNED
};

@interface OCSQLiteCollation : NSObject

@property(strong,readonly) OCSQLiteCollationName name;
@property(copy,class,readonly,nonatomic,nullable) NSComparator sortComparator; //!< Provides a sort comparator to achieve the same sorting as the collation. This is optional.

- (void)registerCollationFor:(OCSQLiteDB *)sqlDB representationHint:(OCSQLiteTextRepresentation)eTextRep; //!< Call that asks the collation to register for the provided sqlite3 instance, ideally for the provided representation type. See https://www.sqlite.org/c3ref/collation_needed.html and https://www.sqlite.org/c3ref/create_collation.html for more information. The standard implementation already wires everything up to call -compare:with: for the various text representations as performant as possible.

- (NSComparisonResult)compare:(NSString *)string1 with:(NSString *)string2; //!< Compares two strings. If present .sortComparator is used by the default implementation. For maximum performance, implement both -compare:with: and provide an optimized sortComparator.

@end

NS_ASSUME_NONNULL_END
