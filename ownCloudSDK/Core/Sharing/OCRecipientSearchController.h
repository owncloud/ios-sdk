//
//  OCRecipientSearchController.h
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

#import "OCCore.h"
#import "OCRecipient.h"

NS_ASSUME_NONNULL_BEGIN

@class OCRecipientSearchController;

@protocol OCRecipientSearchControllerDelegate <NSObject>

- (void)searchControllerHasNewResults:(OCRecipientSearchController *)searchController error:(nullable NSError *)error; //!< Called whenever the search controller has new results or encountered an error.

@optional
- (void)searchController:(OCRecipientSearchController *)searchController isWaitingForResults:(BOOL)isSearching; //!< Called to indicate whether the search controller is waiting for results. Can be used to indicate activity in the UI (like a progress spinner).

@end

@interface OCRecipientSearchController : NSObject

@property(readonly,weak) OCCore *core;

@property(nullable,strong,nonatomic) NSString *searchTerm; //!< The search term to search for
@property(nullable,strong,nonatomic) NSArray <OCShareTypeID> *shareTypes; //!< The share types to consider in the search

@property(assign,nonatomic) NSUInteger maximumResultCount; //!< The maximum number of results to return
@property(assign,nonatomic) BOOL isWaitingForResults; //!< YES if the search controller is waiting for a result.

@property(nullable,strong,nonatomic) NSArray <OCRecipient *> *recipients; //!< The recipients returned from the server

@property(weak) id<OCRecipientSearchControllerDelegate> delegate; //!< Delegate receiving events. Alternatively, it's also possible to KVO-observe this class' properties.

- (instancetype)initWithCore:(OCCore *)core item:(OCItem *)item; //!< Create a new instance with the provided core, suitable for searching recipients for the provided item.

- (void)search; //!< Trigger a rate-limited search. Is automatically called whenever searchTerm or shareTypes are changed.

@end

NS_ASSUME_NONNULL_END
