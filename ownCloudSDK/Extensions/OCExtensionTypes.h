//
//  OCExtensionTypes.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.08.18.
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

#ifndef OCExtensionTypes_h
#define OCExtensionTypes_h

typedef NSString* OCExtensionType; //!< The type of extension.
typedef NSString* OCExtensionLocationIdentifier; //!< Identifier uniquely identifying a particular location in the app / SDK.

typedef NSString* OCExtensionIdentifier; //!< Identifier uniquely identifying the extension.
typedef NSNumber* OCExtensionPriority; //!< Priority of the extension in comparison to others. Smaller values rank higher.

typedef NSDictionary<NSString*,id>* OCExtensionRequirements; //!< A dictionary of requirements.

#endif /* OCExtensionTypes_h */
