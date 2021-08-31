//
//  OCResourceTypes.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.02.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>

typedef NSString* OCResourceSourceIdentifier NS_TYPED_ENUM;

typedef NS_ENUM(NSUInteger, OCResourceSourcePriority)
{
	OCResourceSourcePriorityNormal = 50,
	OCResourceSourcePriorityHigh = 100
};

typedef NSString* OCResourceType NS_TYPED_ENUM; //!< Type of resource, f.ex. thumbnail or avatar
typedef NSString* OCResourceIdentifier; //!< An identifier that identifies the resource, f.ex. the file ID or user name
typedef NSString* OCResourceVersion; //!< A string that can be used to distinguish versions (throug equality comparison), f.ex. ETags or checksums
typedef NSString* OCResourceStructureDescription; //!< A string describing the structure properties of the resource that can affect resource generation or return, such as f.ex. the MIME type (which can change after a rename, without causing ID or version to change)
typedef NSString* OCResourceMetadata; //!< A resource-specific string with metadata on the resource's data 

typedef NS_ENUM(NSUInteger, OCResourceStatus)
{
	OCResourceStatusUnsupported,	//!< Resource is not supported
	OCResourceStatusPlaceholder, 	//!< Placeholder for the requested resource (cache, but do not persist)
	OCResourceStatusFromCache,	//!< Resource from cache
	OCResourceStatusLatest		//!< Resource is latest version
};
