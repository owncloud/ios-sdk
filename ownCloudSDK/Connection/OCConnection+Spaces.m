//
//  OCConnection+Spaces.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 09.12.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCConnection.h"
#import "GADrive.h"
#import "GADriveUpdate.h"
#import "OCConnection+OData.h"
#import "OCConnection+GraphAPI.h"

@implementation OCConnection (Drives)

#pragma mark - Creation
- (nullable NSProgress *)createDriveWithName:(NSString *)name description:(nullable NSString *)description quota:(nullable NSNumber *)quotaBytes completionHandler:(OCConnectionDriveCompletionHandler)completionHandler
{
	GADrive *drive = [GADrive new];
	drive.name = name;
	drive.desc = description;

	if (quotaBytes != nil)
	{
		GAQuota *quota = [GAQuota new];
		quota.total = quotaBytes;
		drive.quota = quota;
	}

	return ([self createODataObject:drive atURL:[self URLForEndpoint:OCConnectionEndpointIDGraphDrives options:nil] requireSignals:[NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable] parameters:nil responseEntityClass:Nil completionHandler:^(NSError * _Nullable error, id  _Nullable response) {
		NSLog(@"New space: %@", response);
		completionHandler(error, (response != nil) ? [OCDrive driveFromGADrive:(GADrive *)response] : nil);
	}]);
}


#pragma mark - Disable/Restore/Delete
- (nullable NSProgress *)_disableDeleteDrive:(OCDrive *)drive doDelete:(BOOL)doDelete completionHandler:(OCConnectionDriveManagementCompletionHandler)completionHandler
{
	// Reference: https://owncloud.dev/apis/http/graph/spaces/#disable-a-space-delete-drivesdrive-id
	OCHTTPRequest *request;
	NSProgress *progress;

	request = [OCHTTPRequest requestWithURL:[[self URLForEndpoint:OCConnectionEndpointIDGraphDrives options:nil] URLByAppendingPathComponent:drive.identifier]];
	request.method = OCHTTPMethodDELETE;
	request.requiredSignals = [NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable];

	if (doDelete) {
		// Reference: https://owncloud.dev/apis/http/graph/spaces/#permanently-delete-a-space-delete-drivesdrive-id
		[request setValue:@"T" forHeaderField:@"Purge"];
	}

	progress = [self sendRequest:request ephermalCompletionHandler:^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
		[self decodeODataResponse:response error:error entityClass:nil options:nil completionHandler:^(NSError * _Nullable error, id  _Nullable response) {
			completionHandler(error);
		}];
	}];

	return (progress);
}


- (nullable NSProgress *)disableDrive:(OCDrive *)drive completionHandler:(OCConnectionDriveManagementCompletionHandler)completionHandler
{
	return ([self _disableDeleteDrive:drive doDelete:NO completionHandler:completionHandler]);
}

- (nullable NSProgress *)restoreDrive:(OCDrive *)drive completionHandler:(OCConnectionDriveManagementCompletionHandler)completionHandler
{
	// Reference: https://owncloud.dev/apis/http/graph/spaces/#restore-a-space-patch-drivesdrive-id
	OCHTTPRequest *request;
	NSProgress *progress;

	request = [OCHTTPRequest requestWithURL:[[self URLForEndpoint:OCConnectionEndpointIDGraphDrives options:nil] URLByAppendingPathComponent:drive.identifier]];
	request.method = OCHTTPMethodPATCH;
	[request setValue:@"T" forHeaderField:@"Restore"];
	request.requiredSignals = [NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable];
	[request setBodyData:[@"{}" dataUsingEncoding:NSUTF8StringEncoding]]; // "This request needs an empty body (–data-raw ‘{}’) to fulfil the standard libregraph specification even when the body is not needed."

	progress = [self sendRequest:request ephermalCompletionHandler:^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
		[self decodeODataResponse:response error:error entityClass:GADrive.class options:nil completionHandler:^(NSError * _Nullable error, id  _Nullable response) {
			completionHandler(error);
		}];
	}];

	return (progress);
}

- (nullable NSProgress *)deleteDrive:(OCDrive *)drive completionHandler:(OCConnectionDriveManagementCompletionHandler)completionHandler
{
	return ([self _disableDeleteDrive:drive doDelete:YES completionHandler:completionHandler]);
}

#pragma mark - Change attributes
- (nullable NSProgress *)updateDrive:(OCDrive *)drive properties:(NSDictionary<OCDriveProperty, id> *)updateProperties completionHandler:(OCConnectionDriveCompletionHandler)completionHandler
{
	// Reference: https://owncloud.dev/apis/http/graph/spaces/#modifying-spaces
	GADriveUpdate *gaDriveUpdate = [GADriveUpdate new];

	for (OCDriveProperty property in updateProperties) {
		if ([property isEqual:OCDrivePropertyQuotaTotal]) {
			gaDriveUpdate.quota = [GAQuota new];
		}
		[gaDriveUpdate setValue:updateProperties[property] forKeyPath:property];
	}

	return ([self updateODataObject:gaDriveUpdate atURL:[[self URLForEndpoint:OCConnectionEndpointIDGraphDrives options:nil] URLByAppendingPathComponent:drive.identifier] requireSignals:[NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable] parameters:nil responseEntityClass:GADrive.class completionHandler:^(NSError * _Nullable error, id  _Nullable response) {
		NSLog(@"Updated space: %@", response);
		completionHandler(error, (response != nil) ? [OCDrive driveFromGADrive:(GADrive *)response] : nil);
	}]);
}

@end
