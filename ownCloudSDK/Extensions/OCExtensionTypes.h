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

typedef NSString* OCExtensionType NS_TYPED_EXTENSIBLE_ENUM; //!< The type of extension.
typedef NSString* OCExtensionLocationIdentifier NS_TYPED_EXTENSIBLE_ENUM; //!< Identifier uniquely identifying a particular location in the app / SDK.

typedef NSString* OCExtensionIdentifier NS_TYPED_EXTENSIBLE_ENUM; //!< Identifier uniquely identifying the extension.

typedef NS_ENUM(NSUInteger,OCExtensionPriority)	 //!< Priority of the extension in comparison to others. Larger values rank higher.
{
	OCExtensionPriorityNoMatch = 0,	//!< Extension doesn't match

	OCExtensionPriorityTypeMatch = 100, //!< Extension type does match
	OCExtensionPriorityLocationMatch = 1000, //!< Extension type and location do match
	OCExtensionPriorityRequirementMatch = 2000, //!< Extension type, location and requirements do match

	OCExtensionPriorityFeatureMatchPlus = 10, //!< Value added to the match score for every preference that is met
};

typedef NSDictionary<NSString*,id>* OCExtensionRequirements; //!< A dictionary of requirements.

#endif /* OCExtensionTypes_h */
