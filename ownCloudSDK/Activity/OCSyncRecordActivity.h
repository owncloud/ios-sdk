//
//  OCSyncRecordActivity.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.01.19.
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

#import "OCActivity.h"
#import "OCCore.h"
#import "OCSyncRecord.h"
#import "OCTypes.h"
#import "OCLogTag.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCSyncRecordActivity : OCActivity

@property(strong) OCSyncRecordID recordID;

@property(assign) OCEventType type;
@property(assign,nonatomic) OCSyncRecordState recordState;
@property(assign,nonatomic) BOOL waitingForUser;
@property(nullable,strong,nonatomic) NSString *waitConditionDescription;

- (instancetype)initWithSyncRecord:(OCSyncRecord *)syncRecord identifier:(OCActivityIdentifier)identifier;

@end

@interface OCActivityUpdate (OCSyncRecord)

- (instancetype)withSyncRecord:(OCSyncRecord *)syncRecord;

@end

NS_ASSUME_NONNULL_END
