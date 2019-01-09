//
//  OCConnection+Jobs.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.01.19.
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

#import "OCConnection.h"
#import "NSError+OCError.h"

@implementation OCConnection (Jobs)

/*
	TODO:
	- make all connection methods return a jobID with their NSProgress
	- make OCConnection accept an optional OCDatabase
	- make OCConnectionQueue accept an optional OCDatabase as storage (updating the connectionRequests table)
	- make below methods use OCDatabase, too
	- keep in mind that a non-existant JobID may occur in the event a request just finished successfully (removing the last request from the table), but the result
	  could not yet be handled by / used to update the SyncEngine.
*/

- (OCConnectionJobID)startNewJobWithRequest:(OCConnectionRequest *)request
{
	return NSUUID.UUID.UUIDString;
}

- (void)addRequest:(OCConnectionRequest *)request toJob:(OCConnectionJobID)jobID
{

}

- (void)completedRequest:(OCConnectionRequest *)request forJob:(OCConnectionJobID)jobID
{

}

- (BOOL)jobExists:(OCConnectionJobID)jobID
{
	return (YES);
}

@end
