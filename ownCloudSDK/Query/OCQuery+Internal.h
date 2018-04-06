//
//  OCQuery+Internal.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 02.04.18.
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

#import "OCQuery.h"

@interface OCQuery (Internal)

#pragma mark - Update full results
- (void)setFullQueryResults:(NSMutableArray <OCItem *> *)fullQueryResults;
- (NSMutableArray <OCItem *> *)fullQueryResults;

#pragma mark - Update processed results
- (void)updateProcessedResultsIfNeeded:(BOOL)ifNeeded;

#pragma mark - Needs recomputation
- (void)setNeedsRecomputation;

#pragma mark - Queue
- (void)queueBlock:(dispatch_block_t)block;

@end
