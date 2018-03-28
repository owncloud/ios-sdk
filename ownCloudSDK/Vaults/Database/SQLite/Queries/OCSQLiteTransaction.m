//
//  OCSQLiteTransaction.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCSQLiteTransaction.h"

@implementation OCSQLiteTransaction

+ (instancetype)transactionWithQueries:(NSArray <OCSQLiteQuery *> *)queries type:(OCSQLiteTransactionType)type completionHandler:(OCSQLiteTransactionCompletionHandler)completionHandler
{
	OCSQLiteTransaction *transaction = [OCSQLiteTransaction new];

	transaction.type = type;
	transaction.queries = queries;
	transaction.completionHandler = completionHandler;

	return (transaction);
}

+ (instancetype)transactionWithBlock:(OCSQLiteTransactionBlock)block type:(OCSQLiteTransactionType)type completionHandler:(OCSQLiteTransactionCompletionHandler)completionHandler
{
	OCSQLiteTransaction *transaction = [OCSQLiteTransaction new];

	transaction.type = type;
	transaction.transactionBlock = block;
	transaction.completionHandler = completionHandler;

	return (transaction);
}

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_commit = YES;
	}

	return(self);
}

@end

NSErrorUserInfoKey OCSQLiteTransactionFailedRequestKey = @"OCSQLiteTransactionFailedRequestKey";
