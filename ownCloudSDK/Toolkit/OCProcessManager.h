//
//  OCProcessManager.h
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

#import <Foundation/Foundation.h>
#import "OCProcessSession.h"
#import "OCLogTag.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCProcessManager : NSObject <OCLogTagging>

@property(nonatomic,readonly,strong) OCProcessSession *processSession; //!< Session of this process
@property(nonatomic,readonly,strong) NSArray <OCProcessSession *> *sessions;

+ (instancetype)sharedProcessManager;

- (void)processDidFinishLaunching; //!< Signal that this process has finished launching
- (void)processWillTerminate; //!< Signal that this process is about to terminate

- (BOOL)isSessionValid:(OCProcessSession *)session usingThoroughChecks:(BOOL)thoroughChecks; //!< Returns YES if the process described by the session is still running

- (BOOL)isSessionWithCurrentProcessBundleIdentifier:(OCProcessSession *)session; //!< Returns YES if the session describes a process with the same bundle identifier as the current process
- (BOOL)isAnyInstanceOfSessionProcessRunning:(OCProcessSession *)session; //!< Returns YES if *a* copy of the process described in the session is currently running (it doesn't have to be the instance described in the session)

- (OCProcessSession *)findLatestSessionForProcessOf:(OCProcessSession *)session; //!< Returns the latest OCProcessSession with the same bundleIdentifier. If none was found, returns the session that was passed in.

- (void)pingSession:(OCProcessSession *)session withTimeout:(NSTimeInterval)timeout completionHandler:(void(^)(BOOL responded, OCProcessSession *latestSession))completionHandler;

#pragma mark - System boot time
+ (nullable NSNumber *)bootTimestamp;

@end

NS_ASSUME_NONNULL_END
