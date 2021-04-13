//
//  OCProcessManager.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.12.18.
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

#import <UIKit/UIKit.h>
#import <sys/types.h>
#import <sys/sysctl.h>

#import "OCProcessManager.h"
#import "OCAppIdentity.h"
#import "OCLogger.h"
#import "OCIPNotificationCenter.h"
#import "OCMacros.h"

@interface OCProcessPing : NSObject <OCLogTagging>
{
	BOOL _responded;
	BOOL _listening;
	OCProcessSession *_session;
	OCIPCNotificationName _pongNotificationName;
	NSTimeInterval _timeout;

	void(^_completionHandler)(BOOL responded, OCProcessSession *latestSession);
}

- (instancetype)initWithSession:(OCProcessSession *)session timeout:(NSTimeInterval)timeout completionHandler:(void(^)(BOOL responded, OCProcessSession *latestSession))completionHandler;
- (void)sendPing;

@end

@interface OCProcessManager ()
{
	OCProcessSession *_processSession;
	NSURL *_processStateDirectoryURL;
	NSMutableArray <OCProcessSession *> *_sessions;
}

@end

@implementation OCProcessManager

#pragma mark - Init & Dealloc
+ (instancetype)sharedProcessManager
{
	static OCProcessManager *sharedProcessManager;
	static dispatch_once_t onceToken;
	__block BOOL notifyFinishedLaunching = NO;

	dispatch_once(&onceToken, ^{
		sharedProcessManager = [OCProcessManager new];
		notifyFinishedLaunching = YES;
	});

	if (notifyFinishedLaunching)
	{
		[sharedProcessManager processDidFinishLaunching];
	}

	return (sharedProcessManager);
}

+ (BOOL)isProcessExtension
{
	return ([NSBundle.mainBundle.bundlePath hasSuffix:@".appex"]);
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_processSession = [[OCProcessSession alloc] initForProcess];

		_processStateDirectoryURL = [[[OCAppIdentity sharedAppIdentity] appGroupContainerURL] URLByAppendingPathComponent:@".processManager" isDirectory:YES];

		[NSFileManager.defaultManager createDirectoryAtURL:_processStateDirectoryURL withIntermediateDirectories:YES attributes:nil error:NULL];

		// Set up ping-pong
		__weak OCProcessManager *weakSelf = self;
		[[OCIPNotificationCenter sharedNotificationCenter] addObserver:self forName:[OCProcessManager pingNotificationNameForSession:_processSession] withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, OCProcessManager *processManager, OCIPCNotificationName  _Nonnull notificationName) {
			OCWLogDebug(@"Received ping (%@) via %@", processManager.processSession.bundleIdentifier, notificationName);

			// Refresh state file
			[processManager writeStateFileForSession:processManager.processSession];

			// Respond with a pong to pings directed at this process
			OCWLogDebug(@"Sending pong (%@)", processManager.processSession.bundleIdentifier);
			[notificationCenter postNotificationForName:[OCProcessManager pongNotificationNameForSession:processManager.processSession] ignoreSelf:YES];
		}];

		// Set up refreshes
		[self loadSessions];

		[[OCIPNotificationCenter sharedNotificationCenter] addObserver:self forName:[OCProcessManager sessionsUpdatedNotification] withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, OCProcessManager *processManager, OCIPCNotificationName  _Nonnull notificationName) {
			[processManager loadSessions];
		}];

		// Set up process notifications
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processWillTerminate) name:UIApplicationWillTerminateNotification object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleStateChange:) name:UIApplicationWillResignActiveNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleStateChange:) name:UIApplicationWillEnterForegroundNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleStateChange:) name:UIApplicationDidEnterBackgroundNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleStateChange:) name:UIApplicationDidBecomeActiveNotification object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleStateChange:) name:NSExtensionHostWillResignActiveNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleStateChange:) name:NSExtensionHostDidEnterBackgroundNotification object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleStateChange:) name:NSExtensionHostWillEnterForegroundNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleStateChange:) name:NSExtensionHostDidBecomeActiveNotification object:nil];

		// Scan for invalid sessions
		[self scanSessions];
	}

	return (self);
}

- (void)dealloc
{
	// Shut down ping-pong
	[[OCIPNotificationCenter sharedNotificationCenter] removeObserver:self forName:[OCProcessManager pingNotificationNameForSession:_processSession]];

	// Shut down refreshes
	[[OCIPNotificationCenter sharedNotificationCenter] removeObserver:self forName:[OCProcessManager sessionsUpdatedNotification]];

	// Remove process notifications
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSExtensionHostWillResignActiveNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSExtensionHostDidEnterBackgroundNotification object:nil];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSExtensionHostWillEnterForegroundNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSExtensionHostDidBecomeActiveNotification object:nil];
}

#pragma mark - IPC
+ (OCIPCNotificationName)pingNotificationNameForSession:(OCProcessSession *)session
{
	return ([@"OCPMPing." stringByAppendingString:session.bundleIdentifier]);
}

+ (OCIPCNotificationName)pongNotificationNameForSession:(OCProcessSession *)session
{
	return ([@"OCPMPong." stringByAppendingString:session.bundleIdentifier]);
}

+ (OCIPCNotificationName)sessionsUpdatedNotification
{
	return ([[[OCAppIdentity sharedAppIdentity] appIdentifierPrefix] stringByAppendingString:@"OCPMSessionUpdate"]);
}

#pragma mark - State files
- (NSURL *)stateFileURLForSession:(OCProcessSession *)session
{
	return ([_processStateDirectoryURL URLByAppendingPathComponent:session.bundleIdentifier isDirectory:NO]);
}

- (OCProcessSession *)readSessionFromStateFileURL:(NSURL *)stateFileURL
{
	NSData *sessionData;
	OCProcessSession *session = nil;

	if ((sessionData = [NSData dataWithContentsOfURL:stateFileURL]) != nil)
	{
		NSError *error = nil;

		session = [NSKeyedUnarchiver unarchivedObjectOfClass:[OCProcessSession class] fromData:sessionData error:&error];

		if (error != nil)
		{
			OCLogError(@"Error reading session state from URL %@", stateFileURL);
		}
	}

	return (session);
}

- (void)writeStateFileForSession:(OCProcessSession *)session
{
	NSURL *stateFileURL;
	NSData *sessionData;

	session.lastActive = [NSDate new];

	if (((sessionData = [NSKeyedArchiver archivedDataWithRootObject:session]) != nil) &&
	    ((stateFileURL = [self stateFileURLForSession:session]) != nil))
	{
		[sessionData writeToURL:stateFileURL atomically:YES];
	}

	[self postUpdateNotification];
}

- (void)removeStateFileForSession:(OCProcessSession *)session
{
	NSURL *stateFileURL;

	if ((stateFileURL = [self stateFileURLForSession:session]) != nil)
	{
		NSError *error = nil;

		if ([[NSFileManager defaultManager] fileExistsAtPath:stateFileURL.path])
		{
			if (![[NSFileManager defaultManager] removeItemAtURL:stateFileURL error:&error])
			{
				OCLogError(@"Error removing state file for session %@", session);
			}
		}
	}

	[self postUpdateNotification];
}

#pragma mark - State tracking
- (void)scanSessions
{
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
		NSError *error = nil;
		NSArray <NSURL *> *stateFileURLs = nil;

		OCLogDebug(@"Starting scan");

		stateFileURLs = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:self->_processStateDirectoryURL includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsSubdirectoryDescendants error:&error];

		for (NSURL *stateFileURL in stateFileURLs)
		{
			OCProcessSession *session;

			if ((session = [self readSessionFromStateFileURL:stateFileURL]) != nil)
			{
				if (![self isSessionValid:session usingThoroughChecks:YES])
				{
					OCLogDebug(@"Scan found invalid session: %@", session);
				}
			}
		}

		OCLogDebug(@"Finishing scan");
	});
}

- (void)loadSessions
{
	NSError *error = nil;
	NSArray <NSURL *> *stateFileURLs = nil;
	NSMutableArray <OCProcessSession *> *sessions = [NSMutableArray new];

	stateFileURLs = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:_processStateDirectoryURL includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsSubdirectoryDescendants error:&error];

	for (NSURL *stateFileURL in stateFileURLs)
	{
		OCProcessSession *session;

		if ((session = [self readSessionFromStateFileURL:stateFileURL]) != nil)
		{
			if ([self isSessionValid:session usingThoroughChecks:NO])
			{
				[sessions addObject:session];
			}
		}
	}

	@synchronized(self)
	{
		[self willChangeValueForKey:@"session"];
		_sessions = sessions;
		[self didChangeValueForKey:@"session"];
	}
}


- (void)postUpdateNotification
{
	[[OCIPNotificationCenter sharedNotificationCenter] postNotificationForName:[OCProcessManager sessionsUpdatedNotification] ignoreSelf:NO];
}

#pragma mark - Events
- (void)processDidFinishLaunching
{
	[self writeStateFileForSession:_processSession];
}

- (void)processWillTerminate
{
	[self removeStateFileForSession:_processSession];
}

- (void)handleStateChange:(NSNotification *)notification
{
	if ([notification.name isEqual:NSExtensionHostDidBecomeActiveNotification])
	{
		OCTLogDebug(@[@"State"], @"Extension Host did become active");
	}

	if ([notification.name isEqual:NSExtensionHostDidEnterBackgroundNotification])
	{
		OCTLogDebug(@[@"State"], @"Extension Host did enter background");
	}

	if ([notification.name isEqual:NSExtensionHostWillResignActiveNotification])
	{
		OCTLogDebug(@[@"State"], @"Extension Host will resign active");
	}

	if ([notification.name isEqual:NSExtensionHostWillEnterForegroundNotification])
	{
		OCTLogDebug(@[@"State"], @"Extension Host will enter foreground");
	}

	if ([notification.name isEqual:UIApplicationDidBecomeActiveNotification])
	{
		OCTLogDebug(@[@"State"], @"App did become active");
	}

	if ([notification.name isEqual:UIApplicationDidEnterBackgroundNotification])
	{
		OCTLogDebug(@[@"State"], @"App did enter background");
	}

	if ([notification.name isEqual:UIApplicationWillResignActiveNotification])
	{
		OCTLogDebug(@[@"State"], @"App will resign active");
	}

	if ([notification.name isEqual:UIApplicationWillEnterForegroundNotification])
	{
		OCTLogDebug(@[@"State"], @"App will enter foreground");
	}
}

#pragma mark - Session validity
- (BOOL)isSessionValid:(OCProcessSession *)session usingThoroughChecks:(BOOL)thoroughChecks
{
	if (session != nil)
	{
		// Own process
		if ([session.bundleIdentifier isEqual:self.processSession.bundleIdentifier])
		{
			// Session for this bundle ID is only valid if its UUID matches this UUID
			return ([session.uuid isEqual:self.processSession.uuid]);
		}

		// Correct boot time
		if (![session.bootTimestamp isEqual:[OCProcessManager bootTimestamp]])
		{
			// Session only valid if boot time stamps match
			return (NO);
		}

		// Session state file checks
		NSURL *sessionStateFileURL = [self stateFileURLForSession:session];

		if (![[NSFileManager defaultManager] fileExistsAtPath:sessionStateFileURL.path])
		{
			// Session only valid if a state file for it exists
			return (NO);
		}
		else
		{
			// Session only valid if UUIDs match
			OCProcessSession *storedSession;

			if ((storedSession = [self readSessionFromStateFileURL:sessionStateFileURL]) != nil)
			{
				if ([storedSession.uuid isEqual:session.uuid])
				{
					// UUIDs match => session valid
					if (thoroughChecks && (session.processType == OCProcessTypeExtension) && ![NSThread isMainThread])
					{
						__block BOOL processDidRespond = NO;

						OCSyncExec(waitForPong, {
							[self pingSession:session withTimeout:1.0 completionHandler:^(BOOL responded, OCProcessSession * _Nonnull latestSession) {
								processDidRespond = responded;

								OCSyncExecDone(waitForPong);
							}];
						});

						if (!processDidRespond)
						{
							// Extension did not respond => remove stale state file for session
							[self removeStateFileForSession:session];

							return (NO);
						}
					}

					return (YES);
				}
			}
		}
	}

	return (NO);
}

#pragma mark - Ping
- (void)pingSession:(OCProcessSession *)session withTimeout:(NSTimeInterval)timeout completionHandler:(void(^)(BOOL responded, OCProcessSession *latestSession))completionHandler
{
	OCProcessPing *ping = [[OCProcessPing alloc] initWithSession:session timeout:timeout completionHandler:completionHandler];

	[ping sendPing];
}

#pragma mark - Session identity
- (BOOL)isSessionWithCurrentProcessBundleIdentifier:(OCProcessSession *)session
{
	// Returns YES if the session describes a process with the same bundle identifier as the current process
	return ([session.bundleIdentifier isEqual:_processSession.bundleIdentifier]);
}

- (BOOL)isAnyInstanceOfSessionProcessRunning:(OCProcessSession *)session
{
	// Returns YES if *a* copy of the process described in the session is currently running (it doesn't have to be the instance described in the session)

	// Get the latest session for this process
	session = [self findLatestSessionForProcessOf:session];

	// Return if that session is running
	return ([self isSessionValid:session usingThoroughChecks:YES]);
}

#pragma mark - Finding latest
- (OCProcessSession *)findLatestSessionForProcessOf:(OCProcessSession *)otherSession
{
	OCProcessSession *latestSession;

	latestSession = [self findLatestSessionForProcessWithBundleIdentifier:otherSession.bundleIdentifier];

	return ((latestSession != nil) ? latestSession : otherSession);
}

- (nullable OCProcessSession *)findLatestSessionForProcessWithBundleIdentifier:(NSString *)bundleIdentifier
{
	@synchronized(self)
	{
		for (OCProcessSession *session in _sessions)
		{
			if ([bundleIdentifier isEqual:session.bundleIdentifier])
			{
				return (session);
			}
		}
	}

	return (nil);
}

#pragma mark - System boot time
+ (NSNumber *)bootTimestamp
{
	struct timeval bootTime;
	size_t bootTimeSize = sizeof(bootTime);

	int mib[] = { CTL_KERN, KERN_BOOTTIME };

	if (sysctl((int *)&mib, sizeof(mib)/sizeof(int), &bootTime, &bootTimeSize, NULL, 0) != -1)
	{
		return (@(bootTime.tv_sec));
	}

	return (nil);
}

#pragma mark - Log tagging
- (nonnull NSArray<OCLogTagName> *)logTags
{
	return (@[@"PROCMAN"]);
}

+ (nonnull NSArray<OCLogTagName> *)logTags
{
	return (@[@"PROCMAN"]);
}

@end

@implementation OCProcessPing

- (instancetype)initWithSession:(OCProcessSession *)session timeout:(NSTimeInterval)timeout completionHandler:(void(^)(BOOL responded, OCProcessSession *latestSession))completionHandler
{
	if ((self = [super init]) != nil)
	{
		_session = session;
		_pongNotificationName = [OCProcessManager pongNotificationNameForSession:_session];
		_completionHandler = [completionHandler copy];
		_timeout = timeout;

		_listening = YES;

		__weak OCProcessPing *weakSelf = self;
		[[OCIPNotificationCenter sharedNotificationCenter] addObserver:self forName:_pongNotificationName withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, OCProcessPing *observer, OCIPCNotificationName  _Nonnull notificationName) {
			OCWLogDebug(@"Received pong from %@", observer->_session.bundleIdentifier);
			[observer receivedPong];
		}];
	}

	return (self);
}

- (void)stopListeningForPong
{
	@synchronized(self)
	{
		if (_listening)
		{
			[[OCIPNotificationCenter sharedNotificationCenter] removeObserver:self forName:_pongNotificationName];
			_listening = NO;
		}
	}
}

- (void)dealloc
{
	[self stopListeningForPong];
}

- (void)sendPing
{
	OCLogDebug(@"Sending ping to %@", _session.bundleIdentifier);
	[[OCIPNotificationCenter sharedNotificationCenter] postNotificationForName:[OCProcessManager pingNotificationNameForSession:_session] ignoreSelf:YES];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_timeout * (NSTimeInterval)NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		@synchronized(self)
		{
			if (!self->_responded)
			{
				OCLogDebug(@"Timeout waiting for pong from %@", self->_session.bundleIdentifier);

				if (self->_completionHandler != nil)
				{
					self->_completionHandler(NO, nil);
					self->_completionHandler = nil;
				}
			}
		}
	});
}

- (void)receivedPong
{
	@synchronized(self)
	{
		OCLogDebug(@"Received pong from %@", _session.bundleIdentifier);
		[self stopListeningForPong];

		_responded = YES;

		if (_completionHandler != nil)
		{
			if (_session != nil)
			{
				_session = [[OCProcessManager sharedProcessManager] readSessionFromStateFileURL:[[OCProcessManager sharedProcessManager] stateFileURLForSession:_session]];
			}

			_completionHandler(YES, _session);
			_completionHandler = nil;
		}
	}
}

#pragma mark - Log tagging
- (nonnull NSArray<OCLogTagName> *)logTags
{
	return (@[@"PROCMAN", @"Ping"]);
}

+ (nonnull NSArray<OCLogTagName> *)logTags
{
	return (@[@"PROCMAN", @"Ping"]);
}

@end
