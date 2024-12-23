//
//  OCShareTypes.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 17.12.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
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

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, OCShareType)
{
	OCShareTypeUserShare = 0,
	OCShareTypeGroupShare = 1,
	OCShareTypeLink = 3,
	OCShareTypeGuest = 4,
	OCShareTypeRemote = 6,

	OCShareTypeUnknown = 255
};

typedef NSNumber* OCShareTypeID; //!< NSNumber-packaged OCShareType value

typedef NS_OPTIONS(NSInteger, OCShareTypesMask)
{
	OCShareTypesMaskNone	   = 0,		//!< No shares
	OCShareTypesMaskUserShare  = (1<<0),	//!<
	OCShareTypesMaskGroupShare = (1<<1),
	OCShareTypesMaskLink       = (1<<2),
	OCShareTypesMaskGuest      = (1<<3),
	OCShareTypesMaskRemote     = (1<<4)
};

typedef NS_OPTIONS(NSInteger, OCSharePermissionsMask)
{
	OCSharePermissionsMaskNone    	= 0,
	OCSharePermissionsMaskInternal 	= 0,		// 0
	OCSharePermissionsMaskRead    	= (1<<0),	// 1
	OCSharePermissionsMaskUpdate  	= (1<<1),	// 2
	OCSharePermissionsMaskCreate  	= (1<<2),	// 4
	OCSharePermissionsMaskDelete  	= (1<<3),	// 8
	OCSharePermissionsMaskShare 	= (1<<4)	// 16
};

typedef NS_ENUM(NSUInteger, OCShareScope)
{
	OCShareScopeSharedByUser,		//!< Return shares for items shared by the user
	OCShareScopeSharedWithUser,		//!< Return shares for items shared with the user (does not include cloud shares)
	OCShareScopePendingCloudShares,		//!< Return pending cloud shares
	OCShareScopeAcceptedCloudShares,	//!< Return accepted cloud shares
	OCShareScopeItem,			//!< Return shares for the provided item itself (current user only)
	OCShareScopeItemWithReshares,		//!< Return shares for the provided item itself (all, not just current user)
	OCShareScopeSubItems			//!< Return shares for items contained in the provided (container) item
};

typedef NS_ENUM(NSUInteger, OCShareCategory)
{
	OCShareCategoryUnknown,
	OCShareCategoryWithMe,
	OCShareCategoryByMe
};

typedef NSString* OCShareOptionKey NS_TYPED_ENUM;
typedef NSDictionary<OCShareOptionKey,id>* OCShareOptions;

typedef NSString* OCShareState NS_TYPED_ENUM;

typedef NSString* OCShareID;

typedef NSString* OCShareActionID; //!< ocis graph action ID
typedef NSString* OCShareRoleID NS_TYPED_ENUM; //!< ocis graph role ID

