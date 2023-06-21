//
// GAHashes.h
// Autogenerated / Managed by ocapigen
// Copyright (C) 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

// occgen: includes
#import <Foundation/Foundation.h>
#import "GAGraphObject.h"

// occgen: type start
NS_ASSUME_NONNULL_BEGIN
@interface GAHashes : NSObject <GAGraphObject, NSSecureCoding>

// occgen: type properties
@property(strong, nullable) NSString *crc32Hash; //!< The CRC32 value of the file (if available). Read-only.
@property(strong, nullable) NSString *quickXorHash; //!< A proprietary hash of the file that can be used to determine if the contents of the file have changed (if available). Read-only.
@property(strong, nullable) NSString *sha1Hash; //!< SHA1 hash for the contents of the file (if available). Read-only.
@property(strong, nullable) NSString *sha256Hash; //!< SHA256 hash for the contents of the file (if available). Read-only.

// occgen: type protected {"locked":true}


// occgen: type end
@end
NS_ASSUME_NONNULL_END

