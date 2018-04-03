//
//  OCSQLiteMigration.h
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
#import "OCSQLiteDB.h"

@class OCSQLiteTableSchema;
@class OCSQLiteDB;

@interface OCSQLiteMigration : NSObject
{
	NSUInteger _appliedSchemas;
}

@property(strong) NSMutableDictionary<NSString *,NSNumber *> *versionsByTableName;

@property(strong) NSMutableArray<OCSQLiteTableSchema *> *applicableSchemas;

@property(strong) NSError *error;

- (void)applySchemasToDatabase:(OCSQLiteDB *)database completionHandler:(OCSQLiteDBCompletionHandler)completionHandler;

@end
