//
//  OCSyncActionLocalImport.h
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

@interface OCSyncActionLocalImport : OCSyncAction

// .localItem == folder to import item into

@property(strong) NSString *filename;
@property(strong) NSURL *importFileURL;
@property(strong) OCItem *placeholderItem;

@property(strong) NSURL *uploadCopyFileURL; //!< COW-clone of the file to import, made just before upload, so the file *can* be updated while uploading

- (instancetype)initWithParentItem:(OCItem *)parentItem filename:(NSString *)filename importFileURL:(NSURL *)importFileURL placeholderItem:(OCItem *)placeholderItem;

@end
