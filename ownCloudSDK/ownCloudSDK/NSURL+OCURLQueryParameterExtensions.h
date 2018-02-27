//
//  NSURL+OCURLQueryParameterExtensions.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 25.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURL (OCURLQueryParameterExtensions)

- (NSURL *)urlByModifyingQueryParameters:(NSMutableArray <NSURLQueryItem *> *(^)(NSMutableArray <NSURLQueryItem *> *queryItems))queryItemsAction;

- (NSURL *)urlByAppendingQueryParameters:(NSDictionary<NSString *,NSString *> *)parameters replaceExisting:(BOOL)replaceExisting;

- (NSDictionary <NSString *,NSString *> *)queryParameters;

@end
