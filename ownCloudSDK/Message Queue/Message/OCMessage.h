//
//  OCMessage.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 17.02.20.
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
#import "OCSyncIssue.h"
#import "OCProcessSession.h"
#import "OCAppIdentity.h"
#import "OCMessagePresenter.h"
#import "OCBookmark.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSUUID* OCMessageUUID;

@class OCCore;

@interface OCMessage : NSObject <NSSecureCoding>

@property(strong,readonly) NSDate *date; //!< Date the record was created
@property(strong,nonatomic,readonly) OCMessageUUID uuid; //!< UUID of this record (identical to syncIssue.uuid for sync issues)

@property(strong,nonatomic,nullable) OCBookmarkUUID bookmarkUUID; //!< UUID of the bookmark that this message belongs to (nil for global issues)

@property(strong) OCSyncIssue *syncIssue; //!< The sync issue represented by this message
@property(strong,nullable) OCSyncIssueChoice *syncIssueChoice; //!< The choice picked for the sync issue

@property(strong,nullable) NSSet<OCMessagePresenterComponentSpecificIdentifier> *processedBy; //!< component-specific identifiers of presenters that have already processed this issue (used to avoids duplicate handling and infinite loops)
@property(strong,nullable) OCProcessSession *lockingProcess; //!< process session of the process currently locking the record. Check for validity to determine if the lock is still valid. If it is valid, do not process this record.

@property(assign) BOOL presentedToUser; //!< Indicator if the message has previously been presented to the user

@property(nonatomic,readonly) BOOL handled; //!< Indicator if the message has already been handled (automatically, or through user interaction)

- (instancetype)initWithSyncIssue:(OCSyncIssue *)syncIssue fromCore:(OCCore *)core;

@end

NS_ASSUME_NONNULL_END
