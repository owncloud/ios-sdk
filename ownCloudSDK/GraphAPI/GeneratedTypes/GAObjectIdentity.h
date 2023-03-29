//
// GAObjectIdentity.h
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
@interface GAObjectIdentity : NSObject <GAGraphObject, NSSecureCoding>

// occgen: type properties
@property(strong, nullable) NSString *issuer; //!< domain of the Provider issuing the identity
@property(strong, nullable) NSString *issuerAssignedId; //!< The unique id assigned by the issuer to the account

// occgen: type protected {"locked":true}


// occgen: type end
@end
NS_ASSUME_NONNULL_END
