//
//  OCSQLiteQuery.h
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
#import "OCSQLiteDB.h"

@interface OCSQLiteQuery : NSObject

@property(strong) NSString *sqlQuery;

@property(strong) NSArray <id<NSObject>> *parameters;
@property(strong) NSDictionary <NSString *, id<NSObject>> *namedParameters;

@property(copy) OCSQLiteDBResultHandler resultHandler;

#pragma mark - Queries
+ (instancetype)query:(NSString *)sqlQuery withParameters:(NSArray <id<NSObject>> *)parameters resultHandler:(OCSQLiteDBResultHandler)resultHandler;
+ (instancetype)query:(NSString *)sqlQuery withNamedParameters:(NSDictionary <NSString *, id<NSObject>> *)parameters resultHandler:(OCSQLiteDBResultHandler)resultHandler;
+ (instancetype)query:(NSString *)sqlQuery resultHandler:(OCSQLiteDBResultHandler)resultHandler;

#pragma mark - SELECT query builder
+ (instancetype)querySelectingColumns:(NSArray<NSString *> *)columnNames fromTable:(NSString *)tableName where:(NSDictionary <NSString *, id<NSObject>> *)matchValues orderBy:(NSString *)orderBy limit:(NSString *)limit resultHandler:(OCSQLiteDBResultHandler)resultHandler;
+ (instancetype)querySelectingColumns:(NSArray<NSString *> *)columnNames fromTable:(NSString *)tableName where:(NSDictionary <NSString *, id<NSObject>> *)matchValues resultHandler:(OCSQLiteDBResultHandler)resultHandler;
+ (instancetype)querySelectingColumns:(NSArray<NSString *> *)columnNames fromTable:(NSString *)tableName where:(NSDictionary <NSString *, id<NSObject>> *)matchValues orderBy:(NSString *)orderBy resultHandler:(OCSQLiteDBResultHandler)resultHandler;

#pragma mark - INSERT query builder
+ (instancetype)queryInsertingIntoTable:(NSString *)tableName rowValues:(NSDictionary <NSString *, id<NSObject>> *)rowValues resultHandler:(OCSQLiteDBInsertionHandler)resultHandler;

#pragma mark - UPDATE query builder
+ (instancetype)queryUpdatingRowsWhere:(NSDictionary <NSString *, id<NSObject>> *)matchValues inTable:(NSString *)tableName withRowValues:(NSDictionary <NSString *, id<NSObject>> *)rowValues completionHandler:(OCSQLiteDBCompletionHandler)completionHandler;
+ (instancetype)queryUpdatingRowWithID:(NSNumber *)rowID inTable:(NSString *)tableName withRowValues:(NSDictionary <NSString *, id<NSObject>> *)rowValues completionHandler:(OCSQLiteDBCompletionHandler)completionHandler;

#pragma mark - DELETE query builder
+ (instancetype)queryDeletingRowsWhere:(NSDictionary <NSString *, id<NSObject>> *)matchValues fromTable:(NSString *)tableName completionHandler:(OCSQLiteDBCompletionHandler)completionHandler;
+ (instancetype)queryDeletingRowWithID:(NSNumber *)rowID fromTable:(NSString *)tableName completionHandler:(OCSQLiteDBCompletionHandler)completionHandler;

@end
