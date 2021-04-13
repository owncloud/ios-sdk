//
//  OCSyncActionCreateFolder.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.09.18.
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

#import "OCSyncAction.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCSyncActionCreateFolder : OCSyncAction

// .localItem == folder to create folder in

@property(strong) NSString *folderName;

@property(nullable,strong) OCItem *placeholderItem;

- (instancetype)initWithParentItem:(OCItem *)parentItem folderName:(NSString *)folderName placeholderCompletionHandler:(nullable OCCorePlaceholderCompletionHandler)placeholderCompletionHandler;

@end

NS_ASSUME_NONNULL_END
