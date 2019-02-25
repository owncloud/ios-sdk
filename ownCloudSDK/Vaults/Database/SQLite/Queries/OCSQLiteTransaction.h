//
//  OCSQLiteTransaction.h
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

#import <Foundation/Foundation.h>
#import "OCSQLiteQuery.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSError * _Nullable(^OCSQLiteTransactionBlock)(OCSQLiteDB *db, OCSQLiteTransaction *transaction);
typedef void(^OCSQLiteTransactionCompletionHandler)(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError * _Nullable error);

typedef NS_ENUM(NSUInteger, OCSQLiteTransactionType) //!< See https://www.sqlite.org/lang_transaction.html
{
	OCSQLiteTransactionTypeDeferred,  //!< SQLite default. Locks on the database are not acquired until the first read or write. Another thread or process could create its own transaction between start of the commit and the first access.
	OCSQLiteTransactionTypeImmediate, //!< Locks database immediately. No other thread/process can write to the database, but continue to read.
	OCSQLiteTransactionTypeExclusive  //!< Locks database exclusively: no other thread/process can read from or write to the database until transaction is finished (except for read_uncommitted connections).
};

@interface OCSQLiteTransaction : NSObject

@property(assign) OCSQLiteTransactionType type;

@property(nullable,strong) NSArray <OCSQLiteQuery *> *queries; //!< An array of queries to execute in this transaction
@property(nullable,copy) OCSQLiteTransactionBlock transactionBlock; //!< A custom block to execute in this transaction

@property(assign) BOOL commit; //!< After running .queries or transactionBlock, this value is checked to see if the transaction should be committed (YES) or rolled back (NO). Defaults to YES.

@property(nullable,copy) OCSQLiteTransactionCompletionHandler completionHandler; //!< Called after commit or rollback of transaction.

@property(nullable,strong) id userInfo; //!< User info. Can be used to store any kind of object.

+ (instancetype)transactionWithQueries:(NSArray <OCSQLiteQuery *> *)queries type:(OCSQLiteTransactionType)type completionHandler:(nullable OCSQLiteTransactionCompletionHandler)completionHandler;
+ (instancetype)transactionWithBlock:(OCSQLiteTransactionBlock)block type:(OCSQLiteTransactionType)type completionHandler:(nullable OCSQLiteTransactionCompletionHandler)completionHandler;

@end

NS_ASSUME_NONNULL_END

extern NSErrorUserInfoKey OCSQLiteTransactionFailedRequestKey;
