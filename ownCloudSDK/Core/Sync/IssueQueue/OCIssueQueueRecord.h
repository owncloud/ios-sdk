//
//  OCIssueQueueRecord.h
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

NS_ASSUME_NONNULL_BEGIN

@interface OCIssueQueueRecord : NSObject <NSSecureCoding>

@property(strong,readonly) NSDate *date; //!< Date the record was created

@property(strong) OCSyncIssue *syncIssue; //!< The queued sync issue
@property(strong,nullable) OCProcessSession *originProcess; //!< Process in which the issue originated. nil if the originProcess isn't capable of handling sync issues.

@property(assign) BOOL presentedToUser; //!< Indicator if the issue has previously been presented to the user

@end

NS_ASSUME_NONNULL_END
