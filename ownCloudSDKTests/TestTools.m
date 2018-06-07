//
//  TestTools.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 07.06.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "TestTools.h"

@implementation OCVault (TestTools)

- (void)eraseSyncWithCompletionHandler:(OCCompletionHandler)completionHandler
{
	dispatch_group_t syncEraseGroup = dispatch_group_create();

	dispatch_group_enter(syncEraseGroup);

	[self eraseWithCompletionHandler:^(id sender, NSError *error) {
		if (completionHandler != nil)
		{
			completionHandler(sender, error);
		}

		dispatch_group_leave(syncEraseGroup);
	}];

	dispatch_group_wait(syncEraseGroup, DISPATCH_TIME_FOREVER);
}

@end
