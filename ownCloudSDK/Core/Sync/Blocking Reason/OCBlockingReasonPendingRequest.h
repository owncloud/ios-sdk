//
//  OCBlockingReasonPendingRequest.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.12.18.
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

#import "OCBlockingReason.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCBlockingReasonPendingRequest : OCBlockingReason

// TODO: Implement blocking reason to check if a request was lost. Find way to distinguish this from finished requests. Could use X-Request-IDs and a cache of completed RequestIDs. Or some novel state tracking SQLite table in a re-engineered OCConnectionQueue.

@end

extern OCBlockingReasonOption OCBlockingReasonOptionResponseReceived; //!< BOOL: response has been received
extern OCBlockingReasonOption OCBlockingReasonOptionRequestID; //!< X-Request-ID of the pending request

NS_ASSUME_NONNULL_END
