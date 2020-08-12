//
//  OCDatabase+Diagnostic.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 31.07.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCDatabase+Diagnostic.h"
#import "OCMacros.h"
#import "OCSQLiteDB.h"
#import "OCSQLiteTransaction.h"
#import "OCSQLiteResultSet.h"

@implementation OCDatabase (Diagnostic)

- (NSArray<OCDiagnosticNode *> *)diagnosticNodesWithContext:(OCDiagnosticContext *)context
{
	NSMutableArray<OCDiagnosticNode *> *nodes = [NSMutableArray new];

	OCWaitInitAndStartTask(dbDiagnostic);

	[self.sqlDB executeTransaction:[OCSQLiteTransaction transactionWithQueries:@[
		// Files, folder and removed count
		[OCSQLiteQuery query:@"SELECT type, COUNT(*) AS cnt, removed FROM metaData GROUP BY type, removed" withParameters:nil resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
			__block NSUInteger totalItems = 0;
			__block NSUInteger removedItems = 0;

			[resultSet iterateUsing:^(OCSQLiteResultSet * _Nonnull resultSet, NSUInteger line, OCSQLiteRowDictionary  _Nonnull rowDictionary, BOOL * _Nonnull stop) {
				NSUInteger cnt = OCTypedCast(rowDictionary[@"cnt"], NSNumber).unsignedIntegerValue;
				OCItemType type = OCTypedCast(rowDictionary[@"type"], NSNumber).integerValue;
				BOOL removed = OCTypedCast(rowDictionary[@"removed"], NSNumber).boolValue;

				if (!removed)
				{
					switch (type)
					{
						case OCItemTypeFile:
							[nodes addObject:[OCDiagnosticNode withLabel:OCLocalized(@"Files") content:@(cnt).stringValue]];
						break;

						case OCItemTypeCollection:
							cnt -= 1; // do not count the root folder
							[nodes addObject:[OCDiagnosticNode withLabel:OCLocalized(@"Folders") content:@(cnt).stringValue]];
						break;
					}
				}
				else
				{
					removedItems += cnt;
				}

				totalItems += cnt;
			} error:NULL];

			if (totalItems > 0)
			{
				[nodes addObject:[OCDiagnosticNode withLabel:OCLocalized(@"Total Items") content:@(totalItems).stringValue]];
			}

			if (removedItems > 0)
			{
				[nodes addObject:[OCDiagnosticNode withLabel:OCLocalized(@"Removed Items") content:@(removedItems).stringValue]];
			}
		}],

		// Update jobs
		[OCSQLiteQuery query:@"SELECT COUNT(*) AS cnt FROM updateJobs" withParameters:nil resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
			__block NSUInteger updateJobs = 0;

			[resultSet iterateUsing:^(OCSQLiteResultSet * _Nonnull resultSet, NSUInteger line, OCSQLiteRowDictionary  _Nonnull rowDictionary, BOOL * _Nonnull stop) {
				updateJobs += OCTypedCast(rowDictionary[@"cnt"], NSNumber).unsignedIntegerValue;
			} error:NULL];

			[nodes addObject:[OCDiagnosticNode withLabel:OCLocalized(@"Scheduled folder scans") content:@(updateJobs).stringValue]];
		}]

	] type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB * _Nonnull db, OCSQLiteTransaction * _Nonnull transaction, NSError * _Nullable error) {
		OCWaitDidFinishTask(dbDiagnostic);
	}]];

	OCWaitForCompletion(dbDiagnostic);

	return (nodes);
}

@end
