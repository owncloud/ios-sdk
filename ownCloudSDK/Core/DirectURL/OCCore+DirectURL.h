//
//  OCCore+DirectURL.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 01.07.19.
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

#import "OCCore.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCCore (DirectURL)

/**
 Provide Direct URL for item fit for streaming. If a local copy exists, can also provide a file URL.

 @param item The item for which the direct URL should be provided.
 @param allowFileURL If YES, allows the return of a file:// URL if the file exists locally.
 @param completionHandler Completion handler to receive any error, the direct URL and a set of HTTP auth headers (if needed).
 */
- (void)provideDirectURLForItem:(OCItem *)item allowFileURL:(BOOL)allowFileURL completionHandler:(void(^)(NSError * _Nullable error, NSURL * _Nullable url, NSDictionary<NSString*,NSString*> * _Nullable httpAuthHeaders))completionHandler;

@end

NS_ASSUME_NONNULL_END
