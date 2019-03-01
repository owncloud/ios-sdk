//
//  OCShare.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.02.18.
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

#import <Foundation/Foundation.h>
#import "OCUser.h"

typedef NS_ENUM(NSInteger, OCShareNativeType)
{
	OCShareNativeTypeUserShare = 0,
	OCShareNativeTypeGroupShare = 1,
	OCShareNativeTypeLink = 3,
	OCShareNativeTypeGuest = 4,
	OCShareNativeTypeRemote = 6
};

typedef NS_OPTIONS(NSInteger, OCShareTypesMask)
{
	OCShareTypesMaskNone	   = 0,		//!< No shares
	OCShareTypesMaskUserShare  = (1<<0),	//!<
	OCShareTypesMaskGroupShare = (1<<1),
	OCShareTypesMaskLink       = (1<<2),
	OCShareTypesMaskGuest      = (1<<3),
	OCShareTypesMaskRemote     = (1<<4)
};

typedef NSString* OCShareOptionKey NS_TYPED_ENUM;
typedef NSDictionary<OCShareOptionKey,id>* OCShareOptions;

@interface OCShare : NSObject <NSSecureCoding>

@property(assign) OCShareTypesMask type; //!< The type of share (i.e. public or user)

@property(strong) NSURL *url; //!< URL of the share (i.e. public link)

@property(strong) NSDate *expirationDate; //!< Expiration date of the share

@property(strong) NSArray<OCUser *> *users; //!< Users included in share

@end

extern OCShareOptionKey OCShareOptionType; //!< The type of share (value: OCShareTypesMask).
extern OCShareOptionKey OCShareOptionUsers; //!< The identifier of the users to share with (value: NSArray<OCUser>*).
extern OCShareOptionKey OCShareOptionExpirationDate; //!< The date of expiration of the share.
