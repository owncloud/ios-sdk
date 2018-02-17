//
//  OCVault.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCBookmark.h"
#import "OCDatabase.h"

@interface OCVault : NSObject
{
	NSUUID *_uuid;
	OCDatabase *_database;
	NSURL *_rootURL;
}

@property(strong) NSUUID *uuid; //!< ID of the vault. Typically the same as the uuid of the OCBookmark it corresponds to.

@property(strong) OCDatabase *database; //!< The vault's database.

@property(readonly) NSURL *rootURL; //!< The vault's root directory

#pragma mark - Init
- (instancetype)init NS_UNAVAILABLE; //!< Always returns nil. Please use the designated initializer instead.
- (instancetype)initWithBookmark:(OCBookmark *)bookmark NS_DESIGNATED_INITIALIZER;

@end
