//
//  OCSignalStorage.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.09.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCSignalRecord.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCSignalStorage : NSObject <NSSecureCoding>
{
	NSMutableSet<OCSignalConsumerUUID> *_consumerUUIDs;
	NSMutableDictionary<OCSignalUUID, OCSignalRecord *> *_recordsBySignalUUID;
}

@end

NS_ASSUME_NONNULL_END
