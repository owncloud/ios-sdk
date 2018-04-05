//
//  OCCore+Internal.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.04.18.
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

#import "OCCore.h"

@interface OCCore (Internal)

#pragma mark - Item List Tasks
- (void)startItemListTaskForPath:(OCPath)path;
- (void)handleUpdatedTask:(OCCoreItemListTask *)task;

#pragma mark - Queue
- (void)queueBlock:(dispatch_block_t)block;

@end
