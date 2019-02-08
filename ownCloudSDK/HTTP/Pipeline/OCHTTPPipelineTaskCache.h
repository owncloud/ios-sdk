//
//  OCHTTPPipelineTaskCache.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 08.02.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCHTTPPipelineBackend.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCHTTPPipelineTaskCache : NSObject
{
	__weak OCHTTPPipelineBackend *_backend;
	NSString *_bundleIdentifier;

	NSMutableDictionary<OCHTTPPipelineTaskID, OCHTTPPipelineTask *> *_taskByTaskID;
	NSMutableDictionary<OCHTTPRequestID, OCHTTPPipelineTask *> *_taskByRequestID;
}

#pragma mark - Init
- (instancetype)initWithBackend:(OCHTTPPipelineBackend *)backend;

#pragma mark - Cache management
- (OCHTTPPipelineTask *)cachedCopyForTask:(OCHTTPPipelineTask *)task storeIfNew:(BOOL)storeIfNew;
- (void)updateWithTask:(OCHTTPPipelineTask *)task remove:(BOOL)remove;

- (nullable OCHTTPPipelineTask *)cachedTaskForPipelineTaskID:(OCHTTPPipelineTaskID)taskID;
- (nullable OCHTTPPipelineTask *)cachedTaskForRequestID:(OCHTTPRequestID)requestID;

@end

NS_ASSUME_NONNULL_END
