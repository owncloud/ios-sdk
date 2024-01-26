//
//  OCDatabase+Scans.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 19.01.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCDatabase+Scans.h"

@implementation OCDatabase (Scans)

+ (NSError *)scanForAndMarkAsRemovedDanglingMetadataInDatabase:(OCSQLiteDB *)sqlDB
{
	NSMutableArray<OCDriveID> *driveIDs = [NSMutableArray new];
	__block NSError *resultError = nil;

	[sqlDB executeTransaction:[OCSQLiteTransaction transactionWithBlock:^NSError * _Nullable(OCSQLiteDB * _Nonnull db, OCSQLiteTransaction * _Nonnull transaction) {
		__block NSError *transactionError = nil;

		// Determine used drive IDs
		[sqlDB executeQuery:[OCSQLiteQuery query:@"SELECT driveID FROM metaData GROUP BY driveID" resultHandler:^(OCSQLiteDB * _Nonnull db, NSError * _Nullable error, OCSQLiteTransaction * _Nullable transaction, OCSQLiteResultSet * _Nullable resultSet) {
			if (error != nil) {
				transactionError = error;
				return;
			}

			[resultSet iterateUsing:^(OCSQLiteResultSet * _Nonnull resultSet, NSUInteger line, OCSQLiteRowDictionary  _Nonnull rowDictionary, BOOL * _Nonnull stop) {
				OCDriveID driveID;

				if ((driveID = OCDriveIDWrap(rowDictionary[@"driveID"])) != nil)
				{
					[driveIDs addObject:driveID];
				}
			} error:&error];
		}]];

		if (transactionError != nil) { return (transactionError); }

		// Iterate over drives
		for (OCDriveID driveID in driveIDs)
		{
			// Determine dangling folders
			NSMutableSet<NSString *> *validPaths = [NSMutableSet new];
			NSMutableSet<NSString *> *danglingFolderPaths = [NSMutableSet new];

			NSString *driveIDComparator = (OCDriveIDUnwrap(driveID) == nil) ? @"IS" : @"=";

			@autoreleasepool {
				OCSQLiteQueryString queryString = [NSString stringWithFormat:@"SELECT path, parentPath FROM metaData WHERE type=1 AND removed=0 AND driveID %@ ? GROUP BY path, removed ORDER BY path", driveIDComparator];

				[sqlDB executeQuery:[OCSQLiteQuery query:queryString withParameters:@[ driveID ] resultHandler:^(OCSQLiteDB * _Nonnull db, NSError * _Nullable error, OCSQLiteTransaction * _Nullable transaction, OCSQLiteResultSet * _Nullable resultSet) {
					if (error != nil) {
						transactionError = error;
						return;
					}

					OCSQLiteRowDictionary rowDict = nil;
					NSError *rowError = nil;

					do {
						NSUInteger i=0;

						// Limit memory consumption by processing 500 paths at a time, then releasing autoreleasepool memory
						@autoreleasepool {
							do {
								i++;
								if ((rowDict = [resultSet nextRowDictionaryWithError:&rowError]) != nil)
								{
									OCPath path = (NSString *)rowDict[@"path"];
									OCPath parentPath = (NSString *)rowDict[@"parentPath"];

									if (parentPath.isRootPath || [validPaths containsObject:parentPath])
									{
										// In root or a known existing path
										[validPaths addObject:path];
									}
									else
									{
										// Not in root and not in a known existing path
										[danglingFolderPaths addObject:path];
									}
								}
							} while ((rowDict != nil) && (i<500) && (rowError==nil));
						}
					} while ((rowDict != nil) && (rowError==nil));
				}]];
			}

			OCLog(@"Valid paths in drive %@: %@", driveID, validPaths);
			OCLog(@"Dangling folder paths in drive %@: %@", driveID, danglingFolderPaths);

			if (transactionError != nil) { return (transactionError); }

			// Mark all dangling folders and all items below their paths as removed
			@autoreleasepool {
				for (OCPath danglingPath in danglingFolderPaths)
				{
					OCSQLiteQueryString queryString = [NSString stringWithFormat:@"UPDATE metaData SET removed=1 WHERE path LIKE ? AND driveID %@ ? AND removed=0", driveIDComparator];

					[sqlDB executeQuery:[OCSQLiteQuery query:queryString withParameters:@[ [danglingPath stringByAppendingString:@"%"], driveID ] resultHandler:^(OCSQLiteDB * _Nonnull db, NSError * _Nullable error, OCSQLiteTransaction * _Nullable transaction, OCSQLiteResultSet * _Nullable resultSet) {
						if (error != nil) {
							transactionError = error;
							return;
						}
					}]];
				}
			}

			if (transactionError != nil) { return (transactionError); }

			// Mark all items without non-removed parent paths as removed
			OCSQLiteQueryString queryString = [NSString stringWithFormat:@"UPDATE metaData SET removed=1 WHERE removed=0 AND driveID %@ ? AND parentPath NOT IN (SELECT path FROM metaData WHERE removed=0 AND type=1 AND driveID %@ ?)", driveIDComparator, driveIDComparator];

			[sqlDB executeQuery:[OCSQLiteQuery query:queryString withParameters:@[ driveID, driveID ] resultHandler:^(OCSQLiteDB * _Nonnull db, NSError * _Nullable error, OCSQLiteTransaction * _Nullable transaction, OCSQLiteResultSet * _Nullable resultSet) {
				if (error != nil) {
					transactionError = error;
					return;
				}
			}]];

			if (transactionError != nil) { return (transactionError); }
		}

		return (transactionError);
	} type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB * _Nonnull db, OCSQLiteTransaction * _Nonnull transaction, NSError * _Nullable error) {
		resultError = error;
	}]];

	return (resultError);
}

@end
