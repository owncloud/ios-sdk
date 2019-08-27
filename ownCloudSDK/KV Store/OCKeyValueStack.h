//
//  OCKeyValueStack.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.08.19.
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

#import <Foundation/Foundation.h>
#import "OCClaim.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCKeyValueStack : NSObject <NSSecureCoding>

- (void)pushObject:(nullable id<NSSecureCoding>)object withClaim:(OCClaim *)claim;
- (void)popObjectWithClaimID:(OCClaimIdentifier)claimIdentifier;

- (BOOL)determineFirstValidObject:(id _Nullable * _Nullable)outObject claimIdentifier:(OCClaimIdentifier _Nullable * _Nullable)outClaimIdentifier removedInvalidEntries:(BOOL * _Nullable)outRemovedInvalidEntries;

@end

NS_ASSUME_NONNULL_END
