//
//  OCCore+Claims.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 29.07.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
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

#import "OCCore.h"
#import "OCClaim.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, OCCoreClaimPurpose)
{
	OCCoreClaimPurposeNone, //!< No purpose for a claim - returns nil
	OCCoreClaimPurposeView	//!< Temporary claim suitable for viewing
};

@interface OCCore (Claims)

- (void)addClaim:(OCClaim *)claim onItem:(OCItem *)item refreshItem:(BOOL)refreshItem completionHandler:(nullable OCCoreClaimCompletionHandler)completionHandler;

- (void)removeClaim:(OCClaim *)claim onItem:(OCItem *)item refreshItem:(BOOL)refreshItem completionHandler:(nullable OCCoreClaimCompletionHandler)completionHandler;

- (void)removeClaimWithIdentifier:(OCClaimIdentifier)claimIdentifier onItem:(OCItem *)item refreshItem:(BOOL)refreshItem completionHandler:(nullable OCCoreClaimCompletionHandler)completionHandler;

- (void)removeClaimsWithExplicitIdentifier:(OCClaimExplicitIdentifier)claimExplicitIdentifier onItem:(OCItem *)item refreshItem:(BOOL)refreshItem completionHandler:(nullable OCCoreClaimCompletionHandler)completionHandler;

- (nullable OCClaim *)generateTemporaryClaimForPurpose:(OCCoreClaimPurpose)purpose;
- (void)removeClaim:(OCClaim *)claim onItem:(OCItem *)item afterDeallocationOf:(NSArray *)objects; //!< Removes the claim when all provided objects have been removed. Can be called repeatedly and works additively.

@end

NS_ASSUME_NONNULL_END
