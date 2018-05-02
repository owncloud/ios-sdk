//
//  OCDatabaseConsistentOperation.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 02.05.18.
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

/*
	OCDatabaseConsistentOperation ensures consistency when dealing with operations that are structured like this:
	- Phase 1: retrieve data from database 			[database not locked]
	- Phase 2: retrieve data from elsewhere (optional)	[database not locked]
	- Phase 3: perform computations				[database not locked]
	- Phase 4: update database with results			[database locked]

	Inconsistencies could occur if the database is changed after phase 1, but before phase 4. OCDatabaseConsistentOperation
	provides a mechanism to detect if the database was changed in that time and ensures consistency if it was.

	To achieve this, OCDatabaseConsistentOperation breaks an operation into

	- preparation: this is phase 1-3
	- operation: this is phase 4

	API users create an OCDatabaseConsistentOperation and call -prepareWithCompletionHandler:, which:
	- runs preparation with an Initial action and stores the result in preOperationResult

	API users then call -performOperation:completionHandler:, which:
	- acquires an exclusive lock on the database (via a transaction)
	- retrieves the current value of the counter identified by .counterIdentifier
	- increments the counter identified by .counterIdentifier by one and saves the value
	- checks if the counter identified by .counterIdentifier still had the same value (prior to incrementing)
		- if YES:
			- executes the operation
		- if NO:
			- run preparation again, this time with Repeated action and waiting for the completionHandler to return
			- executes the operation

	For OCDatabaseConsistentOperation to be efficient, the NO case should be very, very rare. Granted that, it should
	provide consistency at little to no cost, while helping avoid locking the database while idle, blocking concurrent
	operations.
*/

#import <Foundation/Foundation.h>
#import "OCDatabase.h"

typedef NS_ENUM(NSUInteger, OCDatabaseConsistentOperationAction)
{
	OCDatabaseConsistentOperationActionInitial,	//!< Passed on the initial call of the block
	OCDatabaseConsistentOperationActionRepeated	//!< Passed on subsequent calls of the block
};

@class OCDatabaseConsistentOperation;

typedef void(^OCDatabaseConsistentOperationPreparationBlock)(OCDatabaseConsistentOperation *operation, OCDatabaseConsistentOperationAction action, NSNumber *newCounterValue, void(^completionHandler)(NSError *error, id preparationResult));
typedef NSError *(^OCDatabaseConsistentOperationBlock)(OCDatabaseConsistentOperation *operation, id preparationResult, NSNumber *newCounterValue);

@interface OCDatabaseConsistentOperation : NSObject
{
	__weak OCDatabase *_database;

	OCDatabaseCounterIdentifier _counterIdentifier;

	BOOL _initialPreparationDidRun;
	id _preparationResult;
	NSError *_preparationError;
	NSNumber *_preparationCounterValue;

	OCDatabaseConsistentOperationPreparationBlock _preparation;
}

@property(weak) OCDatabase *database;

@property(strong) OCDatabaseCounterIdentifier counterIdentifier;

@property(strong) id preparationResult;
@property(strong) NSError *preparationError;
@property(strong) NSNumber *preparationCounterValue;

@property(copy) OCDatabaseConsistentOperationPreparationBlock preparation;

- (instancetype)initWithDatabase:(OCDatabase *)database counterIdentifier:(OCDatabaseCounterIdentifier)counterIdentifier preparation:(OCDatabaseConsistentOperationPreparationBlock)preparation;

- (void)prepareWithCompletionHandler:(dispatch_block_t)completionHandler;

- (void)performOperation:(OCDatabaseConsistentOperationBlock)operation completionHandler:(OCDatabaseProtectedBlockCompletionHandler)completionHandler;

@end
