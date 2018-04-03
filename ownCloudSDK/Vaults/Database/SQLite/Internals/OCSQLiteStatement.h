//
//  OCSQLiteStatement.h
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

@class OCSQLiteDB;

@interface OCSQLiteStatement : NSObject
{
	__weak OCSQLiteDB *_database;
	sqlite3_stmt *_sqlStatement;
	NSMutableArray <NSString *> *_parameterNamesByIndex;

	NSString *_query;
}

@property(readonly,nonatomic) sqlite3_stmt *sqlStatement;

@property(readonly,weak) OCSQLiteDB *database;

@property(strong) NSString *query;

- (instancetype)initWithSQLStatement:(sqlite3_stmt *)sqlStatement database:(OCSQLiteDB *)database;
+ (instancetype)statementFromQuery:(NSString *)query database:(OCSQLiteDB *)database error:(NSError **)outError;

#pragma mark - Binding values
- (void)bindParameterValue:(id)value atIndex:(int)paramIdx;

- (void)bindParametersFromDictionary:(NSDictionary *)parameterDictionary;
- (void)bindParameters:(NSArray <id<NSObject>> *)values;

#pragma mark - Resetting
- (void)reset;

@end
