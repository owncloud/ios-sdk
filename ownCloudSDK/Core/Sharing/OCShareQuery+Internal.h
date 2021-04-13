//
//  OCShareQuery+Internal.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 13.03.19.
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

#import "OCShareQuery.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCShareQuery (Internal)

- (void)_updateWithRetrievedShares:(NSArray <OCShare *> *)shares forItem:(OCItem *)item scope:(OCShareScope)scope; //!< Replaces the internal array of shares with the provided shares if item and scope match.

- (void)_updateWithAddedShare:(nullable OCShare *)addedShare updatedShare:(nullable OCShare *)updatedShare removedShare:(nullable OCShare *)removedShare; //!< May only be called from OCCore.createShare/.updateShare/.deleteShare.

@end

NS_ASSUME_NONNULL_END
