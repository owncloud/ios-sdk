//
//  OCSyncRecordStatus.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 19.12.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCCore.h"
#import "OCSyncRecord.h"
#import "OCTypes.h"
#import "OCLogTag.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCSyncRecordStatus : NSObject

@property(strong) OCSyncRecordID recordID;

@property(assign) OCEventType type;
@property(assign) OCSyncRecordState state;

@property(strong,nullable) NSString *localizedDescription;
@property(strong,nullable) NSProgress *progress;

@end

NS_ASSUME_NONNULL_END
