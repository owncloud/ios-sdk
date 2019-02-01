//
//  TestTools.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 07.06.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "TestTools.h"
#import "OCMacros.h"
#import "OCItem+OCItemCreationDebugging.h"

@implementation OCVault (TestTools)

- (void)eraseSyncWithCompletionHandler:(OCCompletionHandler)completionHandler
{
	OCSyncExec(erasure, {
		[self eraseWithCompletionHandler:^(id sender, NSError *error) {
			if (completionHandler != nil)
			{
				completionHandler(sender, error);
			}

			OCSyncExecDone(erasure);
		}];
	});
}

@end

@implementation XCTestCase (LocalIDIntegrity)

- (OCDatabaseItemFilter)databaseSanityCheckFilter
{
	// This filter block checks if fileIDs and localIDs are used consistently in database updates, i.e. if different localIDs are used for the same fileID -
	// or if the items that replace placeholder items use a different localID than the placeholder item. Since all changes end up in the database, this provides
	// a high-level sanity check that will assert if violated.
	NSMutableDictionary <OCLocalID, OCFileID> *fileIDByLocalID = [NSMutableDictionary new];
	NSMutableDictionary <OCFileID, OCLocalID> *localIDByFileID = [NSMutableDictionary new];
	NSMutableDictionary <OCPath, OCLocalID> *localIDByPlaceholderPath = [NSMutableDictionary new];

	return (^(NSArray <OCItem *> *items) {
		@synchronized (fileIDByLocalID) {
			for (OCItem *item in items)
			{
				OCFileID fileID = item.fileID;
				OCLocalID localID = item.localID;

				if (item.isPlaceholder)
				{
					if ((localID != nil) && (item.path != nil))
					{
						OCLocalID savedLocalID = localIDByPlaceholderPath[item.path];

						if (savedLocalID == nil)
						{
							localIDByPlaceholderPath[item.path] = localID;
						}
						else
						{
							XCTAssert([savedLocalID isEqualToString:localID], @"***> localID not matching expected localID: path=%@, localID=%@, expectedLocalID=%@", item.path, localID, savedLocalID);
						}
					}
				}
				else
				{
					if ((fileID != nil) && (localID != nil))
					{
						OCLocalID savedLocalID = localIDByFileID[fileID];
						OCFileID savedFileID = fileIDByLocalID[localID];

						if (savedFileID!=nil)
						{
							XCTAssert([savedFileID isEqualToString:fileID], @"***> fileID not matching expected localID: fileID=%@, localID=%@, expectedFileID=%@", fileID, localID, savedFileID);
						}
						else
						{
							fileIDByLocalID[localID] = fileID;
						}

						if (savedLocalID != nil)
						{
							XCTAssert([savedLocalID isEqualToString:localID], @"***> localID not matching expected localID: fileID=%@, localID=%@, expectedLocalID=%@, item=%@ via %@", fileID, localID, savedLocalID, item, item.creationHistory);
						}
						else
						{
							if (item.path != nil)
							{
								if ((savedLocalID = localIDByPlaceholderPath[item.path]) != nil)
								{
									XCTAssert([savedLocalID isEqualToString:localID], @"***> localID not matching expected localID: path=%@, localID=%@, expectedLocalID=%@", item.path, localID, savedLocalID);
								}
							}

							localIDByFileID[fileID] = localID;
						}
					}
				}
			}
		}

		return (items);
	});
}

@end
