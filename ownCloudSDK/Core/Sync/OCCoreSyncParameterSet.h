//
//  OCCoreSyncParameterSet.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.06.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2018, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCCore.h"

@interface OCCoreSyncParameterSet : NSObject

// Shared properties (Scheduler + Result Handler)
@property(strong) OCSyncRecord *syncRecord; //!< The sync record to schedule / handle the result for.
@property(strong) NSError *error; //!< Store any errors that occur here.

// Result Handler properties
@property(strong) OCEvent *event; //!< Event to handle [Result Handler]
@property(strong) NSMutableArray <OCConnectionIssue *> *issues; //!< Any issues that should be relayed to the user [Result Handler]

#pragma mark - Convenienve initializers
+ (instancetype)schedulerSetWithSyncRecord:(OCSyncRecord *)syncRecord;
+ (instancetype)resultHandlerSetWith:(OCSyncRecord *)syncRecord event:(OCEvent *)event issues:(NSMutableArray <OCConnectionIssue *> *)issues;

- (void)addIssue:(OCConnectionIssue *)issue;

@end
