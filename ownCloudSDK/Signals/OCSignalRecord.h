//
//  OCSignalRecord.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.09.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCSignal.h"
#import "OCSignalConsumer.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCSignalRecord : NSObject

@property(readonly,strong) OCSignalUUID signalUUID;

@property(strong,nullable) OCSignal *signal;

@property(strong,nullable) NSArray<OCSignalConsumer *> *consumers;

- (instancetype)initWithSignalUUID:(OCSignalUUID)signalUUID;

@end

NS_ASSUME_NONNULL_END
