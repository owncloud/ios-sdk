//
//  OCShareQuery.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 13.03.19.
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
#import "OCCoreQuery.h"
#import "OCItem.h"
#import "OCShare.h"

NS_ASSUME_NONNULL_BEGIN

@class OCShareQuery;

typedef void(^OCShareQueryChangesAvailableNotificationHandler)(OCShareQuery *query);

@interface OCShareQuery : OCCoreQuery

@property(assign) OCShareScope scope;	//!< The scope of the query
@property(strong,nullable) OCItem *item; //!< The item for scopes OCShareScopeItem, OCShareScopeItemWithReshares and OCShareScopeSubItems.

@property(assign) NSTimeInterval refreshInterval; //!< Minimum amount of time between polling the server to refresh the query's results. A value of 0 turns off polling (default). The refresh interval needs to be set before starting the query.
@property(strong) NSDate *lastRefreshStarted; //!< The last time a refresh was initiated by the core
@property(strong) NSDate *lastRefreshed; //!< The last time the query was refreshed with results from the server

@property(readonly,strong,nonatomic) NSArray <OCShare *> *queryResults; //!< KVO-observable array of OCShares resulting from the query

@property(copy) OCShareQueryChangesAvailableNotificationHandler changesAvailableNotificationHandler;

+ (nullable instancetype)queryWithScope:(OCShareScope)scope item:(nullable OCItem *)item;

@end

NS_ASSUME_NONNULL_END
