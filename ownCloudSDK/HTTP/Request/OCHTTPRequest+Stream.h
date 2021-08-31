//
//  OCHTTPRequest+Stream.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 31.07.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCHTTPRequest.h"
#import "OCRunLoopThread.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCHTTPRequest (Stream)

@property(readonly,class,nonatomic) OCRunLoopThread *sharedStreamThread; //!< RunLoop Thread for scheduling of read and write streams for streaming responses

@property(readonly,nonatomic) BOOL shouldStreamResponse;

- (void)handleResponseStreamData:(nullable NSData *)data forPipelineTask:(OCHTTPPipelineTask *)pipelineTask;
- (void)closeResponseStreamWithError:(nullable NSError *)error forPipelineTask:(OCHTTPPipelineTask *)pipelineTask;

@end

NS_ASSUME_NONNULL_END
