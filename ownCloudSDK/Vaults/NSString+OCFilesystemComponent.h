//
//  NSString+OCFilesystemComponent.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.08.26.
//  Copyright © 2026 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2026, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (OCFilesystemComponent)

@property(strong,readonly,nonatomic,class) NSRegularExpression *ocFilesystemCompatibleCharactersRegex;

@property(readonly,nonatomic) BOOL isValidFilesystemCompatibleComponent; //!< Returns whether the string consists only of characters allowed by the rules for FilesystemCompatibleComponents as defined by +ocFilesystemCompatibleCharactersRegex.

/// Encodes a string to a filesystem-compatible path component and indicates whether the encoding was lossy.
/// If it was lossy, the original string must be preserved by another means.
/// - Parameter outIsLossy: if non-NULL, on return contains information on whether the encoding was lossy.
- (nullable NSString *)encodedFilesystemCompatibleComponentIsLossy:(out BOOL * _Nullable)outIsLossy;

/// Decodes a string from a filesystem-compatible path component to the original string and indicates whether
/// a lossy encoding was used. If encoding was lossy, the original string must be restored by another means.
/// - Parameter outIsLossy: if non-NULL, on return contains information on whether the encoding was lossy.
- (nullable NSString *)decodedFilesystemCompatibleComponentIsLossy:(out BOOL * _Nullable)outIsLossy;

@end

NS_ASSUME_NONNULL_END
