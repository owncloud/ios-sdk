//
//  OCConnectionQueue+BackgroundSessionRecovery.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.07.18.
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

#import "OCConnectionQueue.h"

@interface OCConnectionQueue (BackgroundSessionRecovery)

#pragma mark - Background URL session recovery
+ (void)setCompletionHandler:(dispatch_block_t)completionHandler forBackgroundSessionWithIdentifier:(NSString *)backgroundSessionIdentifier;
+ (dispatch_block_t)completionHandlerForBackgroundSessionWithIdentifier:(NSString *)backgroundSessionIdentifier remove:(BOOL)remove;
+ (NSUUID *)uuidForBackgroundSessionIdentifier:(NSString *)backgroundSessionIdentifier;
+ (NSString *)localBackgroundSessionIdentifierForUUID:(NSUUID *)uuid;
+ (BOOL)backgroundSessionOriginatesLocallyForIdentifier:(NSString *)backgroundSessionIdentifier;
+ (NSArray <NSString *> *)otherBackgroundSessionIdentifiersForUUID:(NSUUID *)uuid;

#pragma mark - State management
- (void)saveState; //!< Store internal state in persistent store (if any)
- (void)restoreState; //!< Restore internal state from persistent store (if any)
- (void)updateStateWithURLSession;  //!< Updates the queue of running requests with state information from the URLSession, returning errors for dropped requests.

@end
