//
//  OCGIdentitySet.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 26.01.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCGraphObject.h"
#import "OCGIdentity.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCGIdentitySet : NSObject <OCGraphObject>

@property(nullable,strong) OCGIdentity *application;
@property(nullable,strong) OCGIdentity *device;
@property(nullable,strong) OCGIdentity *user;

@end

NS_ASSUME_NONNULL_END
