//
//  OCVault+Internal.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.05.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

#import <ownCloudSDK/ownCloudSDK.h>

NS_ASSUME_NONNULL_BEGIN

typedef BOOL(^OCVaultCompactSelector)(OCSyncAnchor _Nullable syncAnchor, OCItem *item);

@interface OCVault (Internal) <NSFileManagerDelegate>

- (void)compactInContext:(nullable void(^)(void(^blockToRunInContext)(OCSyncAnchor syncAnchor)))runInContext withSelector:(OCVaultCompactSelector)selector completionHandler:(nullable OCCompletionHandler)completionHandler; //!< Compacts the vault's contents using the selector to determine which items' files to delete. If the vault is used by an online core, make sure to pass a block for runInContext that runs the passed block inside -[OCCore performProtectedSyncBlock:..] to guarantee integrity.

@end

NS_ASSUME_NONNULL_END
