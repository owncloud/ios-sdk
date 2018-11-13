//
//  OCCore+FileProvider.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 09.06.18.
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

#import "OCCore.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCCore (FileProvider)

@property(class,nonatomic,assign) BOOL hostHasFileProvider;

#pragma mark - Fileprovider tools
- (void)retrieveItemFromDatabaseForFileID:(OCFileID)fileID completionHandler:(void(^)(NSError * __nullable error, OCSyncAnchor __nullable syncAnchor, OCItem * __nullable itemFromDatabase))completionHandler;

#pragma mark - File provider manager
- (nullable NSFileProviderManager *)fileProviderManager;

#pragma mark - Signal changes for items
- (void)signalChangesForItems:(NSArray <OCItem *> *)changedItems;
- (void)signalEnumeratorForContainerItemIdentifier:(NSFileProviderItemIdentifier)changedDirectoryFileID;

@end

NS_ASSUME_NONNULL_END
