//
//  OCBookmark+DBMigration.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 22.03.21.
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

#import "OCBookmark+DBMigration.h"
#import "OCCoreManager.h"
#import "OCDatabase.h"
#import "OCVault.h"

@implementation OCBookmark (DBMigration)

@dynamic needsDatabaseUpgrade;

- (BOOL)needsDatabaseUpgrade
{
	return (
		// No database version => database older than OCDatabaseVersion_11_6
		(self.databaseVersion == OCDatabaseVersionUnknown) ||

	        // Database version < OCDatabaseVersionLatest => needs db update
	        ((self.databaseVersion != OCDatabaseVersionUnknown) && (self.databaseVersion < OCDatabaseVersionLatest))
	);
}

- (BOOL)needsHostUpdate
{
	return ((self.databaseVersion != OCDatabaseVersionUnknown) && (self.databaseVersion > OCDatabaseVersionLatest)); // Database version > OCDatabaseVersionLatest => from newer app version
}

- (void)upgradeDatabaseWithStatusHandler:(OCBookmarkStatusHandler)statusHandler
{
	[OCCoreManager.sharedCoreManager scheduleOfflineOperation:^(OCBookmark * _Nonnull bookmark, dispatch_block_t  _Nonnull completionHandler) {
		OCVault *vault = [[OCVault alloc] initWithBookmark:self];

		vault.database.sqlDB.busyStatusHandler = ^(NSProgress * _Nullable progress) {
			statusHandler(nil, progress);
		};

		[vault openWithCompletionHandler:^(id sender, NSError *openError) {
			[vault closeWithCompletionHandler:^(id sender, NSError *error) {
				vault.database.sqlDB.busyStatusHandler = nil;

				statusHandler(openError, nil);
			}];
		}];
	} forBookmark:self];
}

@end
