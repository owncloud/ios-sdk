//
//  OCBookmark+DBMigration.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 22.03.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCBookmark.h"

typedef void(^OCBookmarkStatusHandler)(NSError * _Nullable error, NSProgress * _Nullable progress);

NS_ASSUME_NONNULL_BEGIN

@interface OCBookmark (DBMigration)

@property(readonly,nonatomic) BOOL needsDatabaseUpgrade; //!< Returns YES if the database of the bookmark needs to be updated.
@property(readonly,nonatomic) BOOL needsHostUpdate; //!< Returns YES if the database of the bookmark is newer than the SDKs version.

- (void)upgradeDatabaseWithStatusHandler:(OCBookmarkStatusHandler)statusHandler; //!< Upgrades the database to the latest schemes and notifies the statusHandler. Done when nil is passed as progress.

@end

NS_ASSUME_NONNULL_END
