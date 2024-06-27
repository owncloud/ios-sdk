//
//  OCProgressManager.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 19.02.19.
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

#import "OCProgressManager.h"
#import "OCProgress.h"
#import "OCHTTPPipelineManager.h"
#import "OCCoreManager.h"
#import "OCCore+SyncEngine.h"

@implementation OCProgressManager
{
	NSMutableDictionary<OCProgressID, OCProgress *> *_progressByID;
}

+ (OCProgressManager *)sharedProgressManager
{
	static dispatch_once_t onceToken;
	static OCProgressManager *sharedProgressManager = nil;

	dispatch_once(&onceToken, ^{
		sharedProgressManager = [OCProgressManager new];
	});

	return (sharedProgressManager);
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_progressByID = [NSMutableDictionary new];
	}

	return (self);
}

- (id<OCProgressResolver>)resolverForPathElement:(OCProgressPathElementIdentifier)pathElementIdentifier withContext:(OCProgressResolutionContext)context
{
	if ([pathElementIdentifier isEqual:OCProgressPathElementIdentifierHTTPRequestRoot])
	{
		return (OCHTTPPipelineManager.sharedPipelineManager);
	}

	if ([pathElementIdentifier isEqual:OCProgressPathElementIdentifierCoreRoot])
	{
		return (OCCoreManager.sharedCoreManager);
	}

	if ([pathElementIdentifier isEqual:OCProgressPathElementIdentifierManagerRoot])
	{
		return (self);
	}

	return (nil);
}

- (NSProgress *)resolveProgress:(OCProgress *)progress withContext:(OCProgressResolutionContext)context
{
	NSProgress *resolvedProgress = nil;

	if ([progress nextPathElementIsLast])
	{
		OCProgressID progressID;

		if ((progressID = progress.nextPathElement) != nil)
		{
			return ([[self registeredProgressWithIdentifier:progressID] resolveWith:nil context:context]);
		}
	}

	return (resolvedProgress);
}

#pragma mark - Registered progress objects
- (nullable OCProgress *)registeredProgressWithIdentifier:(OCProgressID)progressID
{
	if (progressID != nil)
	{
		@synchronized(self)
		{
			return (_progressByID[progressID]);
		}
	}

	return (nil);
}

- (void)registerProgress:(OCProgress *)progress
{
	OCProgressID progressID = progress.identifier;

	if (progressID != nil)
	{
		@synchronized(self)
		{
			_progressByID[progressID] = progress;
		}
	}
}

- (void)unregisterProgress:(OCProgress *)progress
{
	OCProgressID progressID = progress.identifier;

	if (progressID != nil)
	{
		@synchronized(self)
		{
			_progressByID[progressID] = nil;
		}
	}
}

@end

OCProgressPathElementIdentifier OCProgressPathElementIdentifierManagerRoot = @"_manager";
