//
//  OCVault+Prepopulation.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.06.21.
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

#import "OCVault.h"
#import "OCDAVRawResponse.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCVault (Prepopulation)

- (nullable NSProgress *)prepopulateDatabaseWithRawResponse:(OCDAVRawResponse *)davRawResponse progressHandler:(nullable void(^)(NSUInteger folderCount, NSUInteger fileCount))progressHandler completionHandler:(void (^)(NSError *_Nullable error))completionHandler;

- (nullable NSProgress *)prepopulateDatabaseWithInputStream:(NSInputStream *)davInputStream basePath:(NSString *)basePath progressHandler:(nullable void(^)(NSUInteger folderCount, NSUInteger fileCount))progressHandler completionHandler:(void (^)(NSError *_Nullable error))completionHandler;

- (nullable NSProgress *)retrieveMetadataWithCompletionHandler:(void(^)(NSError *_Nullable error, OCDAVRawResponse *_Nullable davRawResponse))completionHandler;
- (nullable NSProgress *)streamMetadataWithCompletionHandler:(void(^)(NSError *_Nullable error, NSInputStream *_Nullable inputStream, NSString *_Nullable basePath))completionHandler;

- (nullable NSError *)eraseDavRawResponses;

@end

NS_ASSUME_NONNULL_END
