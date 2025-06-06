//
// GAIdentity.h
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
@interface GAIdentity : NSObject <GAGraphObject, NSSecureCoding>

// occgen: type properties
@property(strong) NSString *displayName; //!< The identity''s display name. Note that this may not always be available or up to date. For example, if a user changes their display name, the API may show the new value in a future response, but the items associated with the user won''t show up as having changed when using delta.
@property(strong, nullable) NSString *identifier; //!< Unique identifier for the identity.
@property(strong, nullable) NSString *libreGraphUserType; //!< The type of the identity. This can be either "Member" for regular user, "Guest" for guest users or "Federated" for users imported from a federated instance. Can be used by clients to indicate the type of user. For more details, clients should look up and cache the user at the /users endpoint.

// occgen: type protected {"locked":true}


// occgen: type end
@end
NS_ASSUME_NONNULL_END

