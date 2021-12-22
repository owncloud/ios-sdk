//
//  OCSQLiteCollation.m
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

#import "OCSQLiteCollation.h"
#import "OCSQLiteDB.h"

static int collationCompareUTF8(void *pArg, int str1Len, const void *str1Bytes, int str2Len, const void *str2Bytes)
{
	OCSQLiteCollation *collation = (__bridge OCSQLiteCollation *)pArg;
	NSString *str1 = [[NSString alloc] initWithBytes:str1Bytes length:str1Len encoding:NSUTF8StringEncoding];
	NSString *str2 = [[NSString alloc] initWithBytes:str2Bytes length:str2Len encoding:NSUTF8StringEncoding];

	return ((int)[collation compare:str1 with:str2]);
}

static int collationCompareUTF16(void *pArg, int str1Len, const void *str1Bytes, int str2Len, const void *str2Bytes)
{
	OCSQLiteCollation *collation = (__bridge OCSQLiteCollation *)pArg;
	NSString *str1 = [[NSString alloc] initWithBytes:str1Bytes length:str1Len encoding:NSUTF16StringEncoding];
	NSString *str2 = [[NSString alloc] initWithBytes:str2Bytes length:str2Len encoding:NSUTF16StringEncoding];

	return ((int)[collation compare:str1 with:str2]);
}

static int collationCompareUTF16BE(void *pArg, int str1Len, const void *str1Bytes, int str2Len, const void *str2Bytes)
{
	OCSQLiteCollation *collation = (__bridge OCSQLiteCollation *)pArg;
	NSString *str1 = [[NSString alloc] initWithBytes:str1Bytes length:str1Len encoding:NSUTF16BigEndianStringEncoding];
	NSString *str2 = [[NSString alloc] initWithBytes:str2Bytes length:str2Len encoding:NSUTF16BigEndianStringEncoding];

	return ((int)[collation compare:str1 with:str2]);
}

static int collationCompareUTF16LE(void *pArg, int str1Len, const void *str1Bytes, int str2Len, const void *str2Bytes)
{
	OCSQLiteCollation *collation = (__bridge OCSQLiteCollation *)pArg;
	NSString *str1 = [[NSString alloc] initWithBytes:str1Bytes length:str1Len encoding:NSUTF16LittleEndianStringEncoding];
	NSString *str2 = [[NSString alloc] initWithBytes:str2Bytes length:str2Len encoding:NSUTF16LittleEndianStringEncoding];

	return ((int)[collation compare:str1 with:str2]);
}

@implementation OCSQLiteCollation

+ (NSComparator)sortComparator
{
	return (nil);
}

- (void)registerCollationFor:(OCSQLiteDB *)sqlDB representationHint:(OCSQLiteTextRepresentation)eTextRep
{
	sqlite3 *db;

	if ((db = sqlDB.sqlite3DB) != NULL)
	{
		sqlite3_create_collation_v2(db, self.name.UTF8String, OCSQLiteTextRepresentationUTF8,    (__bridge void *)self, collationCompareUTF8,    NULL);
		sqlite3_create_collation_v2(db, self.name.UTF8String, OCSQLiteTextRepresentationUTF16,   (__bridge void *)self, collationCompareUTF16,   NULL);
		sqlite3_create_collation_v2(db, self.name.UTF8String, OCSQLiteTextRepresentationUTF16LE, (__bridge void *)self, collationCompareUTF16LE, NULL);
		sqlite3_create_collation_v2(db, self.name.UTF8String, OCSQLiteTextRepresentationUTF16BE, (__bridge void *)self, collationCompareUTF16BE, NULL);
	}
}

- (NSComparisonResult)compare:(NSString *)string1 with:(NSString *)string2
{
	NSComparator comparator =  [self.class sortComparator];

	if (comparator != nil)
	{
		return (comparator(string1, string2));
	}

	return (NSOrderedSame);
}

@end
