//
//  OCEventRecord.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.09.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCEvent.h"
#import "OCProcessManager.h"
#import "OCProcessSession.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCEventRecord : NSObject <NSSecureCoding>

@property(strong) OCEvent *event;
@property(strong) OCProcessSession *processSession;
@property(strong) OCSyncRecordID syncRecordID;

- (instancetype)initWithEvent:(OCEvent *)event syncRecordID:(OCSyncRecordID)syncRecordID;

@end

NS_ASSUME_NONNULL_END
