//
//  OCGDrive.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 26.01.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCGObject.h"
#import "OCGIdentitySet.h"
#import "OCTypes.h"

@class OCGItemReference;

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCDriveID;
typedef NSString* OCDriveType NS_TYPED_ENUM;

@interface OCGDrive : OCGObject

@property(strong,nullable) OCDriveID id;
@property(strong,nullable) OCGIdentitySet *createdBy;
@property(strong,nullable) NSDate *createdDateTime;
@property(strong,nullable) NSString *driveDescription;
@property(strong,nullable) OCFileETag eTag;
@property(strong,nullable) OCGIdentitySet *lastModifiedBy;
@property(strong,nullable) NSDate *lastModifiedDateTime;
@property(strong,nullable) NSString *name;
@property(strong,nullable) OCGItemReference *parentReference;
@property(strong,nullable) NSURL *webUrl;

@property(strong,nullable) OCGIdentitySet *createdByUser;
@property(strong,nullable) OCGIdentitySet *lastModifiedByUser;

@property(strong,nullable) OCDriveType driveType;

@property(strong,nullable) OCGIdentitySet *owner;

// quota
// items
// root
// special

@end

NS_ASSUME_NONNULL_END
