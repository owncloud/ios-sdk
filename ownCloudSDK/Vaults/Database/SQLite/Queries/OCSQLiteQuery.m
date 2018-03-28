//
//  OCSQLiteQuery.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCSQLiteQuery.h"

@implementation OCSQLiteQuery

+ (instancetype)query:(NSString *)sqlQuery withParameters:(NSArray <id<NSObject>> *)parameters resultHandler:(OCSQLiteDBResultHandler)resultHandler
{
	OCSQLiteQuery *query = [OCSQLiteQuery new];

	query.sqlQuery = sqlQuery;
	query.parameters = parameters;
	query.resultHandler = resultHandler;

	return (query);
}

+ (instancetype)query:(NSString *)sqlQuery withNamedParameters:(NSDictionary <NSString *, id<NSObject>> *)parameters resultHandler:(OCSQLiteDBResultHandler)resultHandler
{
	OCSQLiteQuery *query = [OCSQLiteQuery new];

	query.sqlQuery = sqlQuery;
	query.namedParameters = parameters;
	query.resultHandler = resultHandler;

	return (query);
}

+ (instancetype)query:(NSString *)sqlQuery resultHandler:(OCSQLiteDBResultHandler)resultHandler;
{
	OCSQLiteQuery *query = [OCSQLiteQuery new];

	query.sqlQuery = sqlQuery;
	query.resultHandler = resultHandler;

	return (query);
}

@end
