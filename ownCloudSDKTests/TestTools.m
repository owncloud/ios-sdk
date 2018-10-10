//
//  TestTools.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 07.06.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "TestTools.h"
#import "OCMacros.h"

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
