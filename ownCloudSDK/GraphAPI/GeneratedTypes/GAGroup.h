//
// GAGroup.h
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
@class GAUser;

// occgen: type start
NS_ASSUME_NONNULL_BEGIN
@interface GAGroup : NSObject <GAGraphObject, NSSecureCoding>

// occgen: type properties {"locked":true}
@property(strong, nullable) NSString *identifier; //!< Read-only.
@property(strong, nullable) NSString *desc; //!< An optional description for the group. Returned by default. Supports $filter (eq, ne, not, ge, le, startsWith) and $search.
@property(strong, nullable) NSString *displayName; //!< The display name for the group. This property is required when a group is created and cannot be cleared during updates. Returned by default. Supports $filter (eq, ne, not, ge, le, in, startsWith, and eq on null values), $search, and $orderBy.
@property(strong, nullable) NSArray<GAUser *> *members; //!< Users and groups that are members of this group. HTTP Methods: GET (supported for all groups), Nullable. Supports $expand.
@property(strong, nullable) NSString *onPremisesDomainName; //!< Contains the on-premises domainFQDN, also called dnsDomainName synchronized from the on-premises directory. The property is only populated for customers who are synchronizing their on-premises directory to Azure Active Directory via Azure AD Connect. Read-only. Returned only on $select.
@property(strong, nullable) NSString *onPremisesSamAccountName; //!< Contains the on-premises SAM account name synchronized from the on-premises directory. Read-only.

// occgen: type protected {"locked":true}


// occgen: type end
@end
NS_ASSUME_NONNULL_END

