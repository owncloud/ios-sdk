//
//  OCCoreSyncRoute.h
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
#import "OCCoreSyncContext.h"

typedef BOOL(^OCCoreSyncRouteAction)(OCCore *core, OCCoreSyncContext *syncContext);

@interface OCCoreSyncRoute : NSObject

@property(copy) OCCoreSyncRouteAction scheduler;	//!< Used to schedule network request(s) for an action. Return YES if scheduling worked. Return NO and possibly an error in OCCoreSyncContext.error if not.
@property(copy) OCCoreSyncRouteAction resultHandler;	//!< Used to handle the result of an action (usually following receiving an OCEvent). Return YES if the action succeeded and the sync record has been made obsolete by it (=> can be removed). Return NO if the action has not yet completed or succeeded and add OCConnectionIssue(s) to OCCoreSyncContext.issues where appropriate.

+ (instancetype)routeWithScheduler:(OCCoreSyncRouteAction)scheduler resultHandler:(OCCoreSyncRouteAction)resultHandler;

@end
