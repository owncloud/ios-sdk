//
//  OCSQLiteQuery.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCSQLiteDB.h"

@interface OCSQLiteQuery : NSObject

@property(strong) NSString *sqlQuery;

@property(strong) NSArray <id<NSObject>> *parameters;
@property(strong) NSDictionary <NSString *, id<NSObject>> *namedParameters;

@property(copy) OCSQLiteDBResultHandler resultHandler;

+ (instancetype)query:(NSString *)sqlQuery withParameters:(NSArray <id<NSObject>> *)parameters resultHandler:(OCSQLiteDBResultHandler)resultHandler;
+ (instancetype)query:(NSString *)sqlQuery withNamedParameters:(NSDictionary <NSString *, id<NSObject>> *)parameters resultHandler:(OCSQLiteDBResultHandler)resultHandler;
+ (instancetype)query:(NSString *)sqlQuery resultHandler:(OCSQLiteDBResultHandler)resultHandler;

@end
