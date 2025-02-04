//
//  OCCore+DriveManagement.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.02.25.
//  Copyright © 2025 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2025, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCCore.h"
#import "OCCore+ItemList.h"

@implementation OCCore (DriveManagement)

// Creation
- (nullable NSProgress *)createDriveWithName:(NSString *)name description:(nullable NSString *)description quota:(nullable NSNumber *)quotaBytes completionHandler:(OCCoreDriveCompletionHandler)completionHandler
{
	return ([self.connection createDriveWithName:name description:description quota:quotaBytes completionHandler:^(NSError * _Nullable error, OCDrive * _Nullable newDrive) {
		if (error == nil) {
			[self fetchUpdatesWithCompletionHandler:nil];
		}
		completionHandler(error, newDrive);
	}]);
}

// Disable/Restore/Delete
- (nullable NSProgress *)disableDrive:(OCDrive *)drive completionHandler:(OCCoreCompletionHandler)completionHandler
{
	return ([self.connection disableDrive:drive completionHandler:^(NSError * _Nullable error) {
		if (error == nil) {
			[self fetchUpdatesWithCompletionHandler:nil];
		}
		completionHandler(error);
	}]);
}

- (nullable NSProgress *)restoreDrive:(OCDrive *)drive completionHandler:(OCCoreCompletionHandler)completionHandler
{
	return ([self.connection restoreDrive:drive completionHandler:^(NSError * _Nullable error) {
		if (error == nil) {
			[self fetchUpdatesWithCompletionHandler:nil];
		}
		completionHandler(error);
	}]);
}

- (nullable NSProgress *)deleteDrive:(OCDrive *)drive completionHandler:(OCCoreCompletionHandler)completionHandler
{
	return ([self.connection deleteDrive:drive completionHandler:^(NSError * _Nullable error) {
		if (error == nil) {
			[self fetchUpdatesWithCompletionHandler:nil];
		}
		completionHandler(error);
	}]);
}

// Change attributes
- (nullable NSProgress *)updateDrive:(OCDrive *)drive properties:(NSDictionary<OCDriveProperty, id> *)updateProperties completionHandler:(OCCoreDriveCompletionHandler)completionHandler
{
	return ([self.connection updateDrive:drive properties:updateProperties completionHandler:^(NSError * _Nullable error, OCDrive * _Nullable newDrive) {
		if (error == nil) {
			[self fetchUpdatesWithCompletionHandler:nil];
		}
		completionHandler(error, newDrive);
	}]);
}

@end
