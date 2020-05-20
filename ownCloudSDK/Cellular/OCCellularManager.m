//
//  OCCellularManager.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.05.20.
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

#import "OCCellularManager.h"
#import "OCMacros.h"

@interface OCCellularManager ()
{
	NSMutableArray<OCCellularSwitch *> *_switches;
	NSMutableDictionary<OCCellularSwitchIdentifier, OCCellularSwitch *> *_switchesByIdentifier;
}

@end

@implementation OCCellularManager

@synthesize switches = _switches;

+ (OCCellularManager *)sharedManager
{
	static dispatch_once_t onceToken;
	static OCCellularManager *sharedManager;

	dispatch_once(&onceToken, ^{
		sharedManager = [OCCellularManager new];

		[sharedManager registerSwitch:[[OCCellularSwitch alloc] initWithIdentifier:OCCellularSwitchIdentifierMaster localizedName:OCLocalized(@"Allow cellular access") defaultValue:YES maximumTransferSize:0]];
		[sharedManager registerSwitch:[[OCCellularSwitch alloc] initWithIdentifier:OCCellularSwitchIdentifierAvailableOffline localizedName:OCLocalized(@"Available Offline") defaultValue:YES maximumTransferSize:0]];
	});

	return (sharedManager);
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_switches = [NSMutableArray new];
		_switchesByIdentifier = [NSMutableDictionary new];
	}

	return (self);
}

- (void)registerSwitch:(OCCellularSwitch *)cellularSwitch
{
	@synchronized(self)
	{
		[_switches addObject:cellularSwitch];
		_switchesByIdentifier[cellularSwitch.identifier] = cellularSwitch;
	}
}

- (void)unregisterSwitch:(OCCellularSwitch *)cellularSwitch
{
	@synchronized(self)
	{
		[_switches removeObject:cellularSwitch];
		_switchesByIdentifier[cellularSwitch.identifier] = nil;
	}
}

- (nullable OCCellularSwitch *)switchWithIdentifier:(OCCellularSwitchIdentifier)identifier
{
	@synchronized(self)
	{
		return (_switchesByIdentifier[identifier]);
	}
}

- (BOOL)cellularAccessAllowedFor:(OCCellularSwitchIdentifier)identifier transferSize:(NSUInteger)transferSize
{
	return ([[self switchWithIdentifier:OCCellularSwitchIdentifierMaster] allowsTransferOfSize:transferSize] &&
	    	[[self switchWithIdentifier:identifier] allowsTransferOfSize:transferSize]);
}

@end
