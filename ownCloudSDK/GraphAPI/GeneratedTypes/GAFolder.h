//
// GAFolder.h
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

// occgen: forward declarations
@class GAFolderView;

// occgen: type start
NS_ASSUME_NONNULL_BEGIN
@interface GAFolder : NSObject <GAGraphObject, NSSecureCoding>

// occgen: type properties
@property(strong, nullable) NSNumber *childCount; //!< [integer:int32] Number of children contained immediately within this container.
@property(strong, nullable) GAFolderView *view;

// occgen: type protected {"locked":true}


// occgen: type end
@end
NS_ASSUME_NONNULL_END
