//
//  OCVault+TemporaryTools.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 26.02.25.
//  Copyright © 2025 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2025, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCVault.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^OCVaultTemporaryStorageEraser)(void); //!< Block that, if called, deletes the temporarily allocated filesystem object(s).

@interface OCVault (TemporaryTools)

- (nullable OCVaultTemporaryStorageEraser)createTemporaryUploadContainer:(out NSURL * _Nullable * _Nullable)outURL error:(out NSError * _Nullable * _Nullable)outError; //!< Create a temporary folder in the .temporaryUploadURL of the vault, returning a block to delete it.
- (nullable OCVaultTemporaryStorageEraser)createTemporaryUploadFileFromData:(NSData *)data name:(NSString *)name url:(out NSURL * _Nullable * _Nullable)outURL error:(out NSError * _Nullable * _Nullable)outError; //!< Creates a temporary folder with a temporary file inside, containing the passed data. Returns a block to delete the temporary folder + file.

@end

NS_ASSUME_NONNULL_END
