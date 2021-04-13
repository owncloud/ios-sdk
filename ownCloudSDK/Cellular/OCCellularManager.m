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
#import "OCNetworkMonitor.h"
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

		[sharedManager registerSwitch:[[OCCellularSwitch alloc] initWithIdentifier:OCCellularSwitchIdentifierMain localizedName:OCLocalized(@"Allow cellular access") defaultValue:YES maximumTransferSize:0]];
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

		[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(_handleCellularSwitchChangedNotification:) name:OCCellularSwitchUpdatedNotification object:nil];

		[OCIPNotificationCenter.sharedNotificationCenter addObserver:self forName:OCIPCNotificationNameOCCellularSwitchChangedNotification withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, id  _Nonnull observer, OCIPCNotificationName  _Nonnull notificationName) {
			[NSNotificationCenter.defaultCenter postNotificationName:OCCellularSwitchUpdatedNotification object:nil]; // object must be nil here to indicate a bridged notification (will be replayed over IPC otherwise!)
		}];
	}

	return (self);
}

- (void)dealloc
{
	[OCIPNotificationCenter.sharedNotificationCenter removeObserver:self forName:OCIPCNotificationNameOCCellularSwitchChangedNotification];

	[NSNotificationCenter.defaultCenter removeObserver:self name:OCCellularSwitchUpdatedNotification object:nil];
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
	if (identifier != nil)
	{
		return ([[self switchWithIdentifier:OCCellularSwitchIdentifierMain] allowsTransferOfSize:transferSize] &&
			[[self switchWithIdentifier:identifier] allowsTransferOfSize:transferSize]);
	}

	return ([[self switchWithIdentifier:OCCellularSwitchIdentifierMain] allowsTransferOfSize:transferSize]);
}

- (BOOL)networkAccessAvailableFor:(nullable OCCellularSwitchIdentifier)switchID transferSize:(NSUInteger)transferSize onWifiOnly:(BOOL * _Nullable)outOnWifiOnly
{
	OCCellularSwitch *cellularSwitch = nil;
	BOOL allowedOverCellular;
	BOOL available = NO;

	if ((cellularSwitch = [self switchWithIdentifier:switchID]) == nil)
	{
		cellularSwitch = [self switchWithIdentifier:OCCellularSwitchIdentifierMain];
	}

	allowedOverCellular = [cellularSwitch allowsTransferOfSize:transferSize];

	// Check if cellular usage is allowed
	if (allowedOverCellular)
	{
		// No further checks… this is allowed to use any network and can be scheduled now - IF a network is actually available
		available = OCNetworkMonitor.sharedNetworkMonitor.networkAvailable;
	}
	else
	{
		// Not allowed over cellular - further checks needed
		available = OCNetworkMonitor.sharedNetworkMonitor.networkAvailable && // Check general network availability
			    !OCNetworkMonitor.sharedNetworkMonitor.isExpensive; // No cellular usage allowed - so make this available only if the connection is not expensive (cellular) to avoid requests being returned from NSURLSession
	}

	if (outOnWifiOnly != NULL)
	{
		*outOnWifiOnly = !allowedOverCellular;
	}

	return (available);
}

- (void)_handleCellularSwitchChangedNotification:(NSNotification *)notification
{
	if (notification.object == nil)
	{
		// Remotely originating, reposted notification -> ignore
		return;
	}

	// Locally originating notification -> broadcast remotely
	[OCIPNotificationCenter.sharedNotificationCenter postNotificationForName:OCIPCNotificationNameOCCellularSwitchChangedNotification ignoreSelf:YES];
}

@end

OCIPCNotificationName OCIPCNotificationNameOCCellularSwitchChangedNotification = @"org.owncloud.cellular-switch-changed";
