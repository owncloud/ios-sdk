//
//  OCSQLiteTableSchema.m
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

#import "OCSQLiteTableSchema.h"

@implementation OCSQLiteTableSchema

+ (instancetype)schemaWithTableName:(NSString *)tableName version:(NSUInteger)version creationQueries:(NSArray<NSString *> *)creationQueries upgradeMigrator:(OCSQLiteTableSchemaMigrator)migrator
{
	OCSQLiteTableSchema *schema = [self new];

	schema.tableName = tableName;
	schema.version = version;
	schema.creationQueries = creationQueries;
	schema.upgradeMigrator = migrator;

	return (schema);
}

@end
