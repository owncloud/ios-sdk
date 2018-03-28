//
//  OCSQLiteResultSet.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.03.18.
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
#import <sqlite3.h>

@class OCSQLiteStatement;
@class OCSQLiteResultSet;

typedef id(^OCSQLiteResultSetColumnFilter)(id object);
typedef void(^OCSQLiteResultSetIterator)(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString*, id<NSObject>> *rowDictionary, BOOL *stop);

@interface OCSQLiteResultSet : NSObject
{
	OCSQLiteStatement *_statement;
	sqlite3_stmt *_sqlStatement;

	NSArray<NSString *> *_columnNames;
	NSMutableDictionary<NSNumber *, OCSQLiteResultSetColumnFilter> *filtersByColumnIndex;
}

@property(strong) OCSQLiteStatement *statement;

- (instancetype)initWithStatement:(OCSQLiteStatement *)statement;

- (BOOL)nextRow:(NSError **)error;

- (NSUInteger)iterateUsing:(OCSQLiteResultSetIterator)iterator error:(NSError **)outError;

@end
