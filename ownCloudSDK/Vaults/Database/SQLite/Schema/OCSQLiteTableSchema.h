//
//  OCSQLiteTableSchema.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 02.04.18.
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

@class OCSQLiteDB;
@class OCSQLiteTableSchema;

NS_ASSUME_NONNULL_BEGIN

typedef void(^OCSQLiteTableSchemaMigrator)(OCSQLiteDB *db, OCSQLiteTableSchema *schema, void(^completionHandler)(NSError *error));

@interface OCSQLiteTableSchema : NSObject

@property(strong) NSString *tableName; //!< Name of the table
@property(assign) NSUInteger version;  //!< Version of the schema

@property(strong) NSArray<NSString *> *creationQueries; //!< SQL queries to create table and set it up (f.ex. adding indexes)

@property(nullable,strong) NSArray<NSString *> *openStatements; //!< SQL queries to be run on every open of the database (f.ex. temporary triggers)

@property(nullable,strong) NSProgress *migrationProgress; //!< Progress object that's injected during migration if progress should be reported
@property(nullable,strong) OCSQLiteTableSchemaMigrator upgradeMigrator; //!< Migrator block used to migrate table from preceding version

+ (instancetype)schemaWithTableName:(NSString *)tableName version:(NSUInteger)version creationQueries:(NSArray<NSString *> *)creationQueries openStatements:(nullable NSArray<NSString *> *)openStatements upgradeMigrator:(nullable OCSQLiteTableSchemaMigrator)migrator;

@end

NS_ASSUME_NONNULL_END
