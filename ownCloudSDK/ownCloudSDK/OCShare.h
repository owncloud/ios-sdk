//
//  OCShare.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, OCShareType)
{
	OCShareTypePublicLink,
	OCShareTypeUserShare
};

typedef NSString* OCShareUserIdentifier;
typedef NSString* OCShareOptionKey NS_TYPED_ENUM;
typedef NSDictionary<OCShareOptionKey,id>* OCShareOptions;

@interface OCShare : NSObject <NSSecureCoding>

@property(assign) OCShareType type; //!< The type of share (i.e. public or user)

@property(strong) NSURL *url; //!< URL of the share (i.e. public link)

@property(strong) NSDate *expirationDate; //!< Expiration date of the share

@property(strong) NSArray<OCShareUserIdentifier> *userIdentifiers; //!< Identifiers of the users included in share

@end

extern OCShareOptionKey OCShareOptionType; //!< The type of share (value: OCShareType).
extern OCShareOptionKey OCShareOptionUserIdentifiers; //!< The identifier of the users to share with (value: NSArray<OCShareUserIdentifier>*).
extern OCShareOptionKey OCShareOptionExpirationDate; //!< The date of expiration of the share.
