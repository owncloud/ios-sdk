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

@property(strong) NSUUID *uuid; //!< ID of the vault. Typically the same as the uuid of the OCBookmark it corresponds to.

@property(strong) OCDatabase *database; //!< The vault's database.

@property(readonly) NSURL *rootURL; //!< The vault's root directory

- (instancetype)initWithBookmark:(OCBookmark *)bookmark NS_DESIGNATED_INITIALIZER;

@end
