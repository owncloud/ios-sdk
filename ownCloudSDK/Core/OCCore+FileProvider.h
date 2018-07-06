//
//  OCCore+FileProvider.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 09.06.18.
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

@interface OCCore (FileProvider)

#pragma mark - Fileprovider tools
- (void)retrieveItemFromDatabaseForFileID:(OCFileID)fileID completionHandler:(void(^)(NSError *error, OCSyncAnchor syncAnchor, OCItem *itemFromDatabase))completionHandler;
- (NSURL *)localURLForItem:(OCItem *)item;

@end
