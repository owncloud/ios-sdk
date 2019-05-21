//
//  OCSyncActionUpload.h
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

@interface OCSyncActionUpload : OCSyncAction

@property(strong) OCItem *parentItem;

@property(strong) OCItem *replaceItem;

@property(strong) NSURL *importFileURL;
@property(assign) BOOL importFileIsTemporaryAlongsideCopy;
@property(strong) OCChecksum *importFileChecksum;

@property(strong) NSString *filename;

@property(strong) NSURL *uploadCopyFileURL; //!< COW-clone of the file to import, made just before upload, so the file *can* be updated while uploading

- (instancetype)initWithUploadItem:(OCItem *)uploadItem parentItem:(OCItem *)parentItem filename:(NSString *)filename importFileURL:(NSURL *)importFileURL isTemporaryCopy:(BOOL)isTemporaryCopy;

@end

extern OCSyncActionCategory OCSyncActionCategoryUpload; //!< Action category for uploads
