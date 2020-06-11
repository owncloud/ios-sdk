//
//  OCCore+ConnectionStatus.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.12.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2018, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCCore+ConnectionStatus.h"
#import "OCCore+Internal.h"
#import "OCLogger.h"
#import "OCCore+SyncEngine.h"
#import "OCCoreServerStatusSignalProvider.h"
#import "OCMacros.h"
#import "NSError+OCError.h"
#import "NSError+OCNetworkFailure.h"
#import "OCCore+ItemList.h"

@implementation OCCore (ConnectionStatus)

#pragma mark - Signal providers
- (void)addSignalProvider:(OCCoreConnectionStatusSignalProvider *)provider
{
	if (provider==nil) { return; }

	@synchronized ([OCCoreConnectionStatusSignalProvider class])
	{
		[provider providerWillBeAdded];

		provider.core = self;

		[_connectionStatusSignalProviders addObject:provider];

		[provider providerWasAdded];

		if (self.state != OCCoreStateStopped)
		{
			[self recomputeConnectionStatus];
		}
	}
}

- (void)removeSignalProviders
{
	@synchronized ([OCCoreConnectionStatusSignalProvider class])
	{
		for (OCCoreConnectionStatusSignalProvider *provider in _connectionStatusSignalProviders)
		{
			[provider providerWillBeRemoved];
			provider.core = nil;
			[provider providerWasRemoved];
		}
	}
}

#pragma mark - Connection status computation
- (void)recomputeConnectionStatus
{
	OCCoreConnectionStatus computedConnectionStatus = OCCoreConnectionStatusOffline;
	OCCoreConnectionStatusSignal computedSignal = 0;
	NSString *shortStatusDescription = nil;

	// Compute new signal mask
	@synchronized ([OCCoreConnectionStatusSignalProvider class])
	{
		for (NSUInteger signalBit=0; signalBit < OCCoreConnectionStatusSignalBitCount; signalBit++)
		{
			NSUInteger stateTrue = 0;
			NSUInteger stateFalse = 0;
			NSUInteger stateForceTrue = 0;
			NSUInteger stateForceFalse = 0;
			BOOL isBitSet = NO;
			OCCoreConnectionStatusSignal signal = (1 << signalBit);

			for (OCCoreConnectionStatusSignalProvider *signalProvider in _connectionStatusSignalProviders)
			{
				if (signalProvider.signal == signal)
				{
					switch (signalProvider.state)
					{
						case OCCoreConnectionStatusSignalStateFalse:
							stateFalse++;

							if (shortStatusDescription==nil)
							{
								shortStatusDescription = signalProvider.shortDescription;
							}
						break;

						case OCCoreConnectionStatusSignalStateTrue:
							stateTrue++;
						break;

						case OCCoreConnectionStatusSignalStateForceFalse:
							stateFalse++;
							stateForceFalse++;

							if (shortStatusDescription==nil)
							{
								shortStatusDescription = signalProvider.shortDescription;
							}
						break;

						case OCCoreConnectionStatusSignalStateForceTrue:
							stateTrue++;
							stateForceTrue++;
						break;
					}
				}
			}

			if (stateFalse != 0)
			{
				isBitSet = NO;
			}
			else if (stateTrue != 0)
			{
				isBitSet = YES;
			}

			if (stateForceTrue != 0)
			{
				isBitSet = YES;
			}

			if (stateForceFalse != 0)
			{
				isBitSet = NO;
			}

			computedSignal |= (isBitSet ? signal : 0);
		}

		// Compute new state
		do
		{
			// Reachability
			if ((computedSignal & OCCoreConnectionStatusSignalReachable) == 0)
			{
				break;
			}

			// Availability / Maintenance mode
			if ((computedSignal & OCCoreConnectionStatusSignalAvailable) == 0)
			{
				computedConnectionStatus = OCCoreConnectionStatusUnavailable;
				break;
			}

			// Connecting state
			if ((computedSignal & OCCoreConnectionStatusSignalConnecting) != 0)
			{
				computedConnectionStatus = OCCoreConnectionStatusConnecting;
			}

			// Connection state
			if ((computedSignal & OCCoreConnectionStatusSignalConnected) == 0)
			{
				break;
			}

			// All tests passed => status is online
			computedConnectionStatus = OCCoreConnectionStatusOnline;
		} while(false);
	}

	if (shortStatusDescription == nil)
	{
		switch (computedConnectionStatus)
		{
			case OCCoreConnectionStatusOffline:
				shortStatusDescription = OCLocalized(@"Offline");
			break;

			case OCCoreConnectionStatusUnavailable:
				shortStatusDescription = OCLocalized(@"Server down for maintenance");
			break;

			case OCCoreConnectionStatusConnecting:
				shortStatusDescription = OCLocalized(@"Connecting");
			break;

			case OCCoreConnectionStatusOnline:
				shortStatusDescription = OCLocalized(@"Online");
			break;
		}
	}

	if ((shortStatusDescription != nil) && ![shortStatusDescription isEqual:_connectionStatusShortDescription])
	{
		[self willChangeValueForKey:@"connectionStatusShortDescription"];
		_connectionStatusShortDescription = shortStatusDescription;
		[self didChangeValueForKey:@"connectionStatusShortDescription"];
	}

	[self updateConnectionStatus:computedConnectionStatus withSignal:computedSignal];
}

#pragma mark - Connnection status updates
- (NSString *)_descriptionForConnectionStatus:(OCCoreConnectionStatus)status
{
	switch (status)
	{
		case OCCoreConnectionStatusOffline:
			return (@"offline");
		break;

		case OCCoreConnectionStatusUnavailable:
			return (@"unavailable");
		break;

		case OCCoreConnectionStatusConnecting:
			return (@"connecting");
		break;

		case OCCoreConnectionStatusOnline:
			return (@"online");
		break;
	}

	return (@"unknown");
}

- (void)updateConnectionStatus:(OCCoreConnectionStatus)newStatus withSignal:(OCCoreConnectionStatusSignal)newSignal
{
	OCCoreConnectionStatus oldStatus = _connectionStatus;
	OCCoreConnectionStatusSignal oldSignal = _connectionStatusSignals;
	BOOL reattemptConnect = NO, reloadQueries = NO, updateOnlineConnectionSignal = NO, updateUnavailableConnectionSignal = NO;

	// Property changes
	if (newStatus != _connectionStatus)
	{
		OCLogDebug(@"************ Connection Status will change from %@ to %@ ************", [self _descriptionForConnectionStatus:oldStatus], [self _descriptionForConnectionStatus:newStatus]);

		// Announce change
		[self willChangeValueForKey:@"connectionStatus"];
	}

	if (newSignal != _connectionStatusSignals)
	{
		OCLogDebug(@"************ Connection Status Signal will change from %lu to %lu ************", oldSignal, newSignal);

		// Announce change
		[self willChangeValueForKey:@"connectionStatusSignals"];
	}

	if (newSignal != _connectionStatusSignals)
	{
		// Make change
		_connectionStatusSignals = newSignal;
		[self didChangeValueForKey:@"connectionStatusSignals"];

		OCLogDebug(@"************ Connection Status Signal changed from %lu to %lu ************", oldSignal, newSignal);
	}

	if (newStatus != _connectionStatus)
	{
		// Make change
		_connectionStatus = newStatus;
		[self didChangeValueForKey:@"connectionStatus"];

		OCLogDebug(@"************ Connection Status changed from %@ to %@ ************", [self _descriptionForConnectionStatus:oldStatus], [self _descriptionForConnectionStatus:newStatus]);
	}

	// Determine internal updates
	// - In case server has become reachable and is not (or no longer) in maintenance mode => reattempt connect
	if ((newSignal != oldSignal) && (newStatus == OCCoreConnectionStatusOffline) && ((newSignal & OCCoreConnectionStatusSignalReachable) != 0) &&
	    (self.state == OCCoreStateReady) && (self.connection.state != OCConnectionStateConnecting))
	{
		reattemptConnect = YES;
	}

	// - Reload queries when coming back online
	if ((newStatus != oldStatus) && (newStatus == OCCoreConnectionStatusOnline))
	{
		reloadQueries = YES;
	}

	// - Update connection signals on "unavailable" status changes
	if (((newStatus != OCCoreConnectionStatusUnavailable) != (oldStatus != OCCoreConnectionStatusUnavailable)) || !_connectionStatusInitialUpdate)
	{
		updateUnavailableConnectionSignal = YES;
	}

	// - Update connection signals on "online" status changes
	if (((newStatus == OCCoreConnectionStatusOnline) != (oldStatus == OCCoreConnectionStatusOnline)) || !_connectionStatusInitialUpdate)
	{
		updateOnlineConnectionSignal = YES;
	}

	_connectionStatusInitialUpdate = YES;

	// Internal updates
	if (reattemptConnect || reloadQueries || updateOnlineConnectionSignal)
	{
		[self queueBlock:^{
			if (updateUnavailableConnectionSignal)
			{
				[self->_connection setSignal:OCConnectionSignalIDNetworkAvailable on:(self->_connectionStatus != OCCoreConnectionStatusUnavailable)];
			}

			if (updateOnlineConnectionSignal)
			{
				[self->_connection setSignal:OCConnectionSignalIDCoreOnline on:(self->_connectionStatus == OCCoreConnectionStatusOnline)];
			}

			if (reattemptConnect)
			{
				if ((self->_state == OCCoreStateReady) && (self->_connection.state != OCConnectionStateConnecting))
				{
					[self _attemptConnect];
				}
			}

			if (reloadQueries)
			{
				[self queueConnectivityBlock:^{	// Wait for _attemptConnect to finish
					[self queueBlock:^{ // See if we can proceed
						if (self->_state == OCCoreStateRunning)
						{
							for (OCQuery *query in self->_queries)
							{
								if (query.state == OCQueryStateContentsFromCache)
								{
									[self reloadQuery:query];
								}
							}

							[self setNeedsToProcessSyncRecords];

							[self _pollNextShareQuery];

							[self startCheckingForUpdates];

							[self scheduleNextItemListTask];
						}
					}];
				}];
			}
		}];
	}
}

#pragma mark - OCConnection tracking
- (void)connectionChangedState:(OCConnection *)connection
{
	BOOL hasUnsolvedIssues = NO;

	@synchronized(_unsolvedIssueSignatures)
	{
		hasUnsolvedIssues = (_unsolvedIssueSignatures.count > 0);
	}

	// Update connectionStatusSignalProvider representing connection state
	_connectionStatusSignalProvider.state = (connection.state == OCConnectionStateConnected)  ? OCCoreConnectionStatusSignalStateTrue : OCCoreConnectionStatusSignalStateFalse;
	_connectingStatusSignalProvider.state = (((connection.state == OCConnectionStateConnecting) && // bind this signal provider to the connection's OCConnectionStateConnecting state
	 					  (connection.authenticationMethod.authenticationDataKnownInvalidDate == nil)) || // avoid retries if authentication data is known to be invalid (triggered by state changes) as well as user-visible state changes due to retries
	 					  hasUnsolvedIssues) ? // avoid retries if there are unsolved issues that need fixing first
	 					 	OCCoreConnectionStatusSignalStateTrue :
	 					 	OCCoreConnectionStatusSignalStateFalse;
}

- (void)connectionCertificateUserApproved:(OCConnection *)connection
{
	// User approved a certificate that was blocking connecting
	[self queueBlock:^{
		if ((self->_state == OCCoreStateReady) && (self->_connection.state != OCConnectionStateConnecting))
		{
			[self _attemptConnect];
		}
	}];
}

- (OCHTTPRequestInstruction)connection:(OCConnection *)connection instructionForFinishedRequest:(OCHTTPRequest *)request withResponse:(OCHTTPResponse *)response error:(NSError *)error defaultsTo:(OCHTTPRequestInstruction)defaultInstruction
{
	if (error != nil)
	{
		// Connection dropped errors
		if (error.isNetworkFailureError)
		{
			[_serverStatusSignalProvider reportConnectionRefusedError:error];

			if ([request.requiredSignals containsObject:OCConnectionSignalIDCoreOnline])
			{
				return (OCHTTPRequestInstructionReschedule);
			}
		}

		// Request dropped error
		if ([error isOCErrorWithCode:OCErrorRequestDroppedByURLSession])
		{
			if ([request.requiredSignals containsObject:OCConnectionSignalIDCoreOnline])
			{
				return (OCHTTPRequestInstructionReschedule);
			}
		}

		// Authorization failed
		if ([error isOCErrorWithCode:OCErrorAuthorizationFailed])
		{
			[self sendError:error issue:nil];
		}
	}

	if (response.status.code == OCHTTPStatusCodeSERVICE_UNAVAILABLE)
	{
		[self reportResponseIndicatingMaintenanceMode];

		if ([request.requiredSignals containsObject:OCConnectionSignalIDCoreOnline])
		{
			return (OCHTTPRequestInstructionReschedule);
		}
	}


	return (defaultInstruction);
}

#pragma mark - Reporting
- (void)reportResponseIndicatingMaintenanceMode
{
	[_serverStatusSignalProvider reportResponseIndicatingMaintenanceMode];
}

@end
