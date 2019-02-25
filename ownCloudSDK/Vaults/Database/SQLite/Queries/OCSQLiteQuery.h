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

NS_ASSUME_NONNULL_BEGIN

@interface OCSQLiteQuery : NSObject

@property(strong) NSString *sqlQuery;

@property(strong) NSArray <id<NSObject>> *parameters;
@property(strong) NSDictionary <NSString *, id<NSObject>> *namedParameters;

@property(copy) OCSQLiteDBResultHandler resultHandler;

#pragma mark - Queries
+ (nullable instancetype)query:(NSString *)sqlQuery withParameters:(nullable NSArray <id<NSObject>> *)parameters resultHandler:(nullable OCSQLiteDBResultHandler)resultHandler;
+ (nullable instancetype)query:(NSString *)sqlQuery withNamedParameters:(nullable NSDictionary <NSString *, id<NSObject>> *)parameters resultHandler:(nullable OCSQLiteDBResultHandler)resultHandler;
+ (nullable instancetype)query:(NSString *)sqlQuery resultHandler:(nullable OCSQLiteDBResultHandler)resultHandler;

#pragma mark - SELECT query builder
+ (nullable instancetype)querySelectingColumns:(nullable NSArray<NSString *> *)columnNames fromTable:(NSString *)tableName where:(nullable NSDictionary <NSString *, id<NSObject>> *)matchValues orderBy:(nullable NSString *)orderBy limit:(nullable NSString *)limit resultHandler:(OCSQLiteDBResultHandler)resultHandler;
+ (nullable instancetype)querySelectingColumns:(nullable NSArray<NSString *> *)columnNames fromTable:(NSString *)tableName where:(nullable NSDictionary <NSString *, id<NSObject>> *)matchValues resultHandler:(OCSQLiteDBResultHandler)resultHandler;
+ (nullable instancetype)querySelectingColumns:(nullable NSArray<NSString *> *)columnNames fromTable:(NSString *)tableName where:(nullable NSDictionary <NSString *, id<NSObject>> *)matchValues orderBy:(nullable NSString *)orderBy resultHandler:(OCSQLiteDBResultHandler)resultHandler;

#pragma mark - INSERT query builder
+ (nullable instancetype)queryInsertingIntoTable:(NSString *)tableName rowValues:(NSDictionary <NSString *, id<NSObject>> *)rowValues resultHandler:(nullable OCSQLiteDBInsertionHandler)resultHandler;

#pragma mark - UPDATE query builder
+ (nullable instancetype)queryUpdatingRowsWhere:(NSDictionary <NSString *, id<NSObject>> *)matchValues inTable:(NSString *)tableName withRowValues:(NSDictionary <NSString *, id<NSObject>> *)rowValues completionHandler:(nullable OCSQLiteDBCompletionHandler)completionHandler;
+ (nullable instancetype)queryUpdatingRowWithID:(NSNumber *)rowID inTable:(NSString *)tableName withRowValues:(NSDictionary <NSString *, id<NSObject>> *)rowValues completionHandler:(nullable OCSQLiteDBCompletionHandler)completionHandler;

#pragma mark - DELETE query builder
+ (nullable instancetype)queryDeletingRowsWhere:(NSDictionary <NSString *, id<NSObject>> *)matchValues fromTable:(NSString *)tableName completionHandler:(nullable OCSQLiteDBCompletionHandler)completionHandler;
+ (nullable instancetype)queryDeletingRowWithID:(NSNumber *)rowID fromTable:(NSString *)tableName completionHandler:(nullable OCSQLiteDBCompletionHandler)completionHandler;

@end

NS_ASSUME_NONNULL_END

#define OCSQLiteNullProtect(object) (((object)!=nil) ? (object) : NSNull.null)
#define OCSQLiteNullResolved(object) ([(object) isKindOfClass:[NSNull class]] ? nil : (object))
