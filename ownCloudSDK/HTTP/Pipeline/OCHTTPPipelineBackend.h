//
//  OCHTTPPipelineBackend.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.02.19.
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
#import "OCBookmark.h"
#import "OCSQLiteDB.h"
#import "OCHTTPTypes.h"

@class OCHTTPPipelineTask;

NS_ASSUME_NONNULL_BEGIN

@interface OCHTTPPipelineBackend : NSObject
{
	OCSQLiteDB *_sqlDB;
	BOOL isOpen;
}

- (instancetype)initWithSQLDB:(nullable OCSQLiteDB *)sqlDB;

#pragma mark - Open & Close
- (void)openWithCompletionHandler:(OCCompletionHandler)completionHandler;
- (void)closeWithCompletionHandler:(OCCompletionHandler)completionHandler;

#pragma mark - Task access
- (NSError *)addPipelineTask:(OCHTTPPipelineTask *)task;
- (NSError *)updatePipelineTask:(OCHTTPPipelineTask *)task;
- (NSError *)removePipelineTask:(OCHTTPPipelineTask *)task;

- (OCHTTPPipelineTask *)retrieveTaskForID:(OCHTTPPipelineTaskID)taskID error:(NSError **)outDBError;

@end

NS_ASSUME_NONNULL_END
