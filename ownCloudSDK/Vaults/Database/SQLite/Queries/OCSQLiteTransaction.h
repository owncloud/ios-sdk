//
//  OCSQLiteTransaction.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCSQLiteQuery.h"

typedef NSError *(^OCSQLiteTransactionBlock)(OCSQLiteDB *db, OCSQLiteTransaction *transaction);
typedef void(^OCSQLiteTransactionCompletionHandler)(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error);

typedef NS_ENUM(NSUInteger, OCSQLiteTransactionType) //!< See https://www.sqlite.org/lang_transaction.html
{
	OCSQLiteTransactionTypeDeferred,  //!< SQLite default. Locks on the database are not acquired until the first read or write. Another thread or process could create its own transaction between start of the commit and the first access.
	OCSQLiteTransactionTypeImmediate, //!< Locks database immediately. No other thread/process can write to the database, but continue to read.
	OCSQLiteTransactionTypeExclusive  //!< Locks database exclusively: no other thread/process can read from or write to the database until transaction is finished (except for read_uncommitted connections).
};

@interface OCSQLiteTransaction : NSObject

@property(assign) OCSQLiteTransactionType type;

@property(strong) NSArray <OCSQLiteQuery *> *queries; //!< An array of queries to execute in this transaction
@property(copy) OCSQLiteTransactionBlock transactionBlock; //!< A custom block to execute in this transaction

@property(assign) BOOL commit; //!< After running .queries or transactionBlock, this value is checked to see if the transaction should be committed (YES) or rolled back (NO). Defaults to YES.

@property(copy) OCSQLiteTransactionCompletionHandler completionHandler; //!< Called after commit or rollback of transaction.

+ (instancetype)transactionWithQueries:(NSArray <OCSQLiteQuery *> *)queries type:(OCSQLiteTransactionType)type completionHandler:(OCSQLiteTransactionCompletionHandler)completionHandler;
+ (instancetype)transactionWithBlock:(OCSQLiteTransactionBlock)block type:(OCSQLiteTransactionType)type completionHandler:(OCSQLiteTransactionCompletionHandler)completionHandler;

@end

extern NSErrorUserInfoKey OCSQLiteTransactionFailedRequestKey;
