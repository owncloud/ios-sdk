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
#import "OCRecipient.h"

typedef NS_ENUM(NSInteger, OCShareType)
{
	OCShareTypeUserShare = 0,
	OCShareTypeGroupShare = 1,
	OCShareTypeLink = 3,
	OCShareTypeGuest = 4,
	OCShareTypeRemote = 6,

	OCShareTypeUnknown = 255
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

typedef NS_OPTIONS(NSInteger, OCSharePermissionsMask)
{
	OCSharePermissionsMaskNone    	= 0,
	OCSharePermissionsMaskRead    	= (1<<0),
	OCSharePermissionsMaskUpdate  	= (1<<1),
	OCSharePermissionsMaskCreate  	= (1<<2),
	OCSharePermissionsMaskDelete  	= (1<<3),
	OCSharePermissionsMaskShare 	= (1<<4)
};

typedef NSString* OCShareOptionKey NS_TYPED_ENUM;
typedef NSDictionary<OCShareOptionKey,id>* OCShareOptions;

typedef NSString* OCShareID;

#import "OCItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCShare : NSObject <NSSecureCoding>

@property(nullable,strong) OCShareID identifier; //!< Server-issued unique identifier of the share

@property(assign) OCShareType type; //!< The type of share (i.e. public or user)

@property(strong) OCPath itemPath; //!< Path of the shared item
@property(assign) OCItemType itemType; //!< Type of the shared item
@property(nullable,strong) OCUser *itemOwner; //!< Owner of the item
@property(nullable,strong) NSString *itemMIMEType; //!< MIME-Type of the shared item

@property(nullable,strong) NSString *name; //!< Name of the share (maximum length: 64 characters)
@property(nullable,strong) NSString *token; //!< share token
@property(nullable,strong) NSURL *url; //!< URL of the share (i.e. public link)

@property(assign) OCSharePermissionsMask permissions; //!< Mask of permissions set on the share
@property(assign,nonatomic) BOOL canRead;
@property(assign,nonatomic) BOOL canUpdate;
@property(assign,nonatomic) BOOL canCreate;
@property(assign,nonatomic) BOOL canDelete;
@property(assign,nonatomic) BOOL canReadWrite;
@property(assign,nonatomic) BOOL canShare;

@property(nullable,strong) NSDate *creationDate; //!< Creation date of the share
@property(nullable,strong) NSDate *expirationDate; //!< Expiration date of the share

@property(nullable,strong) OCUser *owner; //!< Owner of the share
@property(nullable,strong) OCRecipient *recipient; //!< Recipient of the share

@end

extern OCShareOptionKey OCShareOptionType; //!< The type of share (value: OCShareTypesMask).
extern OCShareOptionKey OCShareOptionUsers; //!< The identifier of the users to share with (value: NSArray<OCUser>*).
extern OCShareOptionKey OCShareOptionExpirationDate; //!< The date of expiration of the share.

NS_ASSUME_NONNULL_END
