//
//  OCSQLiteTransaction.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.03.18.
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
