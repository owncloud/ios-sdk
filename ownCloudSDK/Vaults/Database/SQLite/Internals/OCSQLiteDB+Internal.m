//
//  OCSQLiteDB+Internal.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 08.01.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

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
}

@end
