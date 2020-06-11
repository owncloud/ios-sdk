//
//  OCTUSJob.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 29.04.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCTUSHeader.h"
#import "OCChecksum.h"
#import "OCEventTarget.h"

NS_ASSUME_NONNULL_BEGIN

@class OCTUSJobSegment;

@interface OCTUSJob : NSObject <NSSecureCoding>

@property(strong) OCTUSHeader *header;

@property(strong) NSURL *fileURL;
@property(strong) NSURL *segmentFolderURL;

@property(strong,nullable) NSNumber *uploadOffset;

@property(assign) NSUInteger maxSegmentSize;

@property(strong,nullable) NSURL *creationURL; //!< URL to direct creation requests to
@property(strong,nullable) NSURL *uploadURL; //!< URL to direct upload requests to

@property(strong,nullable) NSString *futureItemPath; //!< Future path of the item on the server (after upload)

@property(strong,nullable) NSString *fileName;
@property(strong,nullable) NSNumber *fileSize;
@property(strong,nullable) NSDate *fileModDate;
@property(strong,nullable) OCChecksum *fileChecksum;

@property(strong,nullable) OCEventTarget *eventTarget;

- (instancetype)initWithHeader:(OCTUSHeader *)header segmentFolderURL:(NSURL *)segmentFolder fileURL:(NSURL *)fileURL creationURL:(NSURL *)creationURL;

- (nullable OCTUSJobSegment *)requestSegmentFromOffset:(NSUInteger)offset withSize:(NSUInteger)size error:(NSError * _Nullable * _Nullable)outError;

- (void)destroy; //!< Erase the .segmentFolder

@end


@interface OCTUSJobSegment : NSObject <NSSecureCoding>

@property(assign) NSUInteger offset;
@property(assign) NSUInteger size;
@property(strong,nullable) NSURL *url;

@property(readonly,nonatomic) BOOL isValid;

@end


NS_ASSUME_NONNULL_END
