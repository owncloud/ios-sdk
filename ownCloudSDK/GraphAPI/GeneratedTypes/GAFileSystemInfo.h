//
// GAFileSystemInfo.h
// Autogenerated / Managed by ocapigen
// Copyright (C) 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
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
@interface GAFileSystemInfo : NSObject <GAGraphObject, NSSecureCoding>

// occgen: type properties
@property(strong, nullable) NSDate *createdDateTime; //!< [string:date-time] The UTC date and time the file was created on a client. | pattern: ^[0-9]{4,}-(0[1-9]|1[012])-(0[1-9]|[12][0-9]|3[01])[Tt]([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]([.][0-9]{1,12})?([Zz]|[+-][0-9][0-9]:[0-9][0-9])$
@property(strong, nullable) NSDate *lastAccessedDateTime; //!< [string:date-time] The UTC date and time the file was last accessed. Available for the recent file list only. | pattern: ^[0-9]{4,}-(0[1-9]|1[012])-(0[1-9]|[12][0-9]|3[01])[Tt]([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]([.][0-9]{1,12})?([Zz]|[+-][0-9][0-9]:[0-9][0-9])$
@property(strong, nullable) NSDate *lastModifiedDateTime; //!< [string:date-time] The UTC date and time the file was last modified on a client. | pattern: ^[0-9]{4,}-(0[1-9]|1[012])-(0[1-9]|[12][0-9]|3[01])[Tt]([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]([.][0-9]{1,12})?([Zz]|[+-][0-9][0-9]:[0-9][0-9])$

// occgen: type protected {"locked":true}


// occgen: type end
@end
NS_ASSUME_NONNULL_END

