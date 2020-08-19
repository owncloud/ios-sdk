//
//  OCSQLiteDB+Internal.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 08.01.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCSQLiteDB+Internal.h"
#import "OCSQLiteStatement.h"
#import "OCLogger.h"

@implementation OCSQLiteDB (Internal)

- (void)startTrackingStatement:(OCSQLiteStatement *)statement
{
	@synchronized(_liveStatements)
	{
		[_liveStatements addObject:statement];
	}
}

- (void)stopTrackingStatement:(OCSQLiteStatement *)statement;
{
	@synchronized(_liveStatements)
	{
		[_liveStatements removeObject:statement];
	}

	@synchronized(OCSQLiteStatement.class)
	{
		[_cachedStatements removeObject:statement];
	}
}

- (void)releaseAllLiveStatementResources
{
	@synchronized(_liveStatements)
	{
		if (_liveStatements.count > 0)
		{
			OCLogDebug(@"Releasing the resources of up to %lu live statements", (unsigned long)_liveStatements.count);
		}

		for (OCSQLiteStatement *statement in _liveStatements)
		{
			[statement releaseSQLObjects];
		}

		[_liveStatements removeAllObjects];
	}

	@synchronized(OCSQLiteStatement.class)
	{
		[_cachedStatements removeAllObjects];
	}
}

- (void)logMemoryStatistics
{
	if ((_db != NULL) && [OCLogger logsForLevel:OCLogLevelDebug])
	{
		int ops[] = {
			SQLITE_STATUS_MEMORY_USED,
			SQLITE_STATUS_PAGECACHE_USED,
			SQLITE_STATUS_PAGECACHE_OVERFLOW,
			SQLITE_STATUS_PAGECACHE_SIZE
		};
		char *labels[] = {
			"Memory Used   ",
			"Pagecache Used",
			"Pagecache Oflw",
			"Pagecache Size"
		};

		OCLog(@"SQLITE MEMORY | CURRENT | HIGHWATER");
		for (NSUInteger idx=0; idx < sizeof(ops) / sizeof(int); idx++)
		{
			sqlite_int64 current = 0;
			sqlite_int64 highwater = 0;

			sqlite3_status64(ops[idx], &current, &highwater, 0);

			OCLog(@"%s | %lld | %lld", labels[idx], current, highwater);
		}

		int db_ops[] = {
			SQLITE_DBSTATUS_LOOKASIDE_USED,
			SQLITE_DBSTATUS_CACHE_USED,
			SQLITE_DBSTATUS_SCHEMA_USED,
			SQLITE_DBSTATUS_STMT_USED
		};
		char *db_labels[] = {
			"Lookaside Used",
			"Cache Used    ",
			"Schema Used   ",
			"Statement Used"
		};

		for (NSUInteger idx=0; idx < sizeof(db_ops) / sizeof(int); idx++)
		{
			int current = 0;
			int highwater = 0;

			sqlite3_db_status(_db, db_ops[idx], &current, &highwater, 0);

			OCLogDebug(@"%s | %d | %d", db_labels[idx], current, highwater);
		}
	}
}

@end
