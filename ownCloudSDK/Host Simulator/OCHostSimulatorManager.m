//
//  OCHostSimulatorManager.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 12.10.20.
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

#import "OCHostSimulatorManager.h"
#import "OCExtension.h"
#import "OCExtension+HostSimulation.h"
#import "OCExtensionManager.h"
#import "OCMacros.h"

@interface OCHostSimulatorManager ()
{
	NSMapTable <id, id<OCConnectionHostSimulator>> *_hostSimulatorsByOwner;
}
@end

@implementation OCHostSimulatorManager

+ (OCHostSimulatorManager *)sharedManager
{
	static dispatch_once_t onceToken;
	static OCHostSimulatorManager *sharedManager;

	dispatch_once(&onceToken, ^{
		sharedManager = [OCHostSimulatorManager new];
	});

	return (sharedManager);
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_hostSimulatorsByOwner = [NSMapTable weakToStrongObjectsMapTable];
	}

	return (self);
}

- (NSArray<OCHostSimulationIdentifier> *)activeSimulations
{
	return (OCTypedCast([self classSettingForOCClassSettingsKey:OCClassSettingsKeyHostSimulatorActiveSimulations], NSArray));
}

- (BOOL)isHostSimulatorEnabledFromExtension:(OCExtension *)extension
{
	return ([self.activeSimulations containsObject:extension.identifier]);
}

- (nullable id<OCConnectionHostSimulator>)hostSimulatorForLocation:(OCExtensionLocationIdentifier)locationIdentifier for:(nullable id)owner
{
	id<OCConnectionHostSimulator> hostSimulator;

	if ((hostSimulator = [_hostSimulatorsByOwner objectForKey:owner]) == nil)
	{
		NSError *error = nil;
		NSArray<OCExtensionMatch *> *matches;
		OCExtensionContext *context = [OCExtensionContext contextWithLocation:[OCExtensionLocation locationOfType:OCExtensionTypeHostSimulator identifier:locationIdentifier] requirements:nil preferences:nil];
		NSArray<OCHostSimulationIdentifier> *activeSimulations = [self activeSimulations];

		if ((matches = [OCExtensionManager.sharedExtensionManager provideExtensionsForContext:context error:&error]) != nil)
		{
			for (OCExtensionMatch *match in matches)
			{
				if ([activeSimulations containsObject:match.extension.identifier])
				{
					if ((hostSimulator = [match.extension provideObjectForContext:context]) != nil)
					{
						break;
					}
				}
			}
		}

		[_hostSimulatorsByOwner setObject:hostSimulator forKey:owner];
	}

	return (hostSimulator);
}

+ (OCClassSettingsIdentifier)classSettingsIdentifier
{
	return (OCClassSettingsIdentifierHostSimulatorManager);
}

+ (nullable NSDictionary<OCClassSettingsKey,id> *)defaultSettingsForIdentifier:(nonnull OCClassSettingsIdentifier)identifier
{
	return (@{
		OCClassSettingsKeyHostSimulatorActiveSimulations : @[]
	});
}

@end

OCExtensionType OCExtensionTypeHostSimulator = @"host-simulator";

OCExtensionLocationIdentifier OCExtensionLocationIdentifierAllCores = @"all-cores";
OCExtensionLocationIdentifier OCExtensionLocationIdentifierAccountSetup = @"account-setup";

OCClassSettingsIdentifier OCClassSettingsIdentifierHostSimulatorManager = @"host-simulator";
OCClassSettingsKey OCClassSettingsKeyHostSimulatorActiveSimulations = @"active-simulations";

