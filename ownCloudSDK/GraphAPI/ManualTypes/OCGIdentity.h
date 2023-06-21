//
//  OCGIdentity.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 26.01.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCGraphObject.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCGIdentityID;

@interface OCGIdentity : NSObject <OCGraphObject>

@property(strong,nullable) OCGIdentityID id;
@property(strong,nullable) NSString *displayName;

@end

NS_ASSUME_NONNULL_END
