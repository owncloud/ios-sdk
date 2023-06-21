//
//  OCCodeFile.h
//  ocapigen
//
//  Created by Felix Schwarz on 27.01.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCCodeFileSegment.h"
#import "OCCodeGenerator.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCCodeFile : NSObject

@property(weak,nullable) OCCodeGenerator *generator;

@property(strong) NSURL *url;
@property(strong) NSMutableArray<OCCodeFileSegment *> *segments;

- (instancetype)initWithURL:(NSURL *)url generator:(OCCodeGenerator *)generator;

- (OCCodeFileSegment *)segmentForName:(OCCodeFileSegmentName)name;
- (OCCodeFileSegment *)segmentForName:(OCCodeFileSegmentName)name after:(nullable OCCodeFileSegment *)afterSegment;

- (void)read;
- (NSString *)composedFileContents;
- (nullable NSError *)write;

@end

NS_ASSUME_NONNULL_END
