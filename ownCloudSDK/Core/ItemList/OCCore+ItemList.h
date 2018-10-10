//
//  OCCore+ItemList.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 23.07.18.
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

@interface OCCore (ItemList)

#pragma mark - Item List Tasks
- (OCCoreItemListTask *)startItemListTaskForPath:(OCPath)path;
- (BOOL)startItemListTask:(OCCoreItemListTask *)task;
- (void)handleUpdatedTask:(OCCoreItemListTask *)task;

#pragma mark - Check for updates
- (void)startCheckingForUpdates; //!< Checks the root directory for a changed ETag and recursively traverses the entire tree for all updated and new items.

- (void)_handleRetrieveItemListEvent:(OCEvent *)event sender:(id)sender;

@end
