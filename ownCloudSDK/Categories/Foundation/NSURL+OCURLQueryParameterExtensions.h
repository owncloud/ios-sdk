//
//  NSURL+OCURLQueryParameterExtensions.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 25.02.18.
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURL (OCURLQueryParameterExtensions)

- (nullable NSURL *)urlByModifyingQueryParameters:(nullable NSMutableArray <NSURLQueryItem *> *(^)(NSMutableArray <NSURLQueryItem *> *queryItems))queryItemsAction;

- (nullable NSURL *)urlByAppendingQueryParameters:(NSDictionary<NSString *,NSString *> *)parameters replaceExisting:(BOOL)replaceExisting;

@property(readonly,nullable) NSDictionary <NSString *,NSString *> *queryParameters;

@property(readonly) NSString *hostAndPort;

@property(readonly,nullable) NSURL *rootURL; //!< Returns just scheme + host, f.ex. "https://owncloud.com/" for "https://owncloud.com/about/"

@end

NS_ASSUME_NONNULL_END
