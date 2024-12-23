//
//  OCConnection+GraphAPI.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 26.01.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCConnection+GraphAPI.h"
#import "OCConnection+OData.h"
#import "GAIdentitySet.h"
#import "GADrive.h"
#import "GAPermission.h"
#import "GAUnifiedRoleDefinition.h"
#import "GAODataError.h"
#import "GAODataErrorMain.h"
#import "GAGraphData+Decoder.h"
#import "OCODataDecoder.h"
#import "OCMacros.h"
#import "OCShare+GraphAPI.h"

@implementation OCConnection (GraphAPI)

- (NSArray<OCDrive *> *)drives
{
	@synchronized (_drivesByID)
	{
		return (_drives);
	}
}

- (void)setDrives:(NSArray<OCDrive *> *)drives
{
	NSMutableDictionary<OCDriveID, OCDrive *> *drivesByID = [NSMutableDictionary new];

	for (OCDrive *drive in drives)
	{
		if (drive.identifier != nil)
		{
			drivesByID[drive.identifier] = drive;
		}
	}

	@synchronized (_drivesByID)
	{
		_drives = drives;
		[_drivesByID setDictionary:drivesByID];
	}
}

- (OCDrive *)driveWithID:(OCDriveID)driveID
{
	@synchronized (_drivesByID)
	{
		return (_drivesByID[driveID]);
	}
}

- (void)driveWithID:(OCDriveID)driveID completionHandler:(void (^)(OCDrive * _Nullable))completionHandler
{
	OCDrive *drive;

	if ((drive = [self driveWithID:driveID]) != nil)
	{
		completionHandler(drive);
	}
	else
	{
		[self retrieveDriveListWithCompletionHandler:^(NSError * _Nullable error, NSArray<OCDrive *> * _Nullable drives) {
			completionHandler([self driveWithID:driveID]);
		}];
	}
}

- (nullable NSProgress *)retrieveDriveListWithCompletionHandler:(OCRetrieveDriveListCompletionHandler)completionHandler
{
	return ([self requestODataAtURL:[self URLForEndpoint:OCConnectionEndpointIDGraphMeDrives options:nil] requireSignals:[NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable] selectEntityID:nil selectProperties:nil filterString:nil parameters:nil entityClass:GADrive.class options:nil completionHandler:^(NSError * _Nullable error, id  _Nullable response) {
		NSMutableArray<OCDrive *> *ocDrives = nil;

		if (error == nil)
		{
			// Convert GADrives to OCDrives
			NSArray<GADrive *> *gaDrives;

			if ((gaDrives = OCTypedCast(response, NSArray)) != nil)
			{
				ocDrives = [NSMutableArray new];

				for (GADrive *drive in gaDrives)
				{
					OCDrive *ocDrive;

					if ((ocDrive = [OCDrive driveFromGADrive:drive]) != nil)
					{
						[ocDrives addObject:ocDrive];
					}
				}

				if (ocDrives.count > 0)
				{
					self.drives = ocDrives;
				}
			}
		}

		OCLogDebug(@"Drives response: drives=%@, error=%@", ocDrives, error);

		completionHandler(error, (ocDrives.count > 0) ? ocDrives : nil);
	}]);
}

#pragma mark - Permissions
- (NSURL *)permissionsURLForDriveWithID:(OCDriveID)driveID fileID:(nullable OCFileID)fileID permissionID:(nullable OCShareID)shareID
{
	NSURL *permissionURL;

	if (fileID == nil)
	{
		// Drive permissions
		permissionURL = [[self URLForEndpoint:OCConnectionEndpointIDGraphDrivePermissions options:nil] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@/root/permissions", driveID]];
	}
	else
	{
		// Item permissions
		permissionURL = [[self URLForEndpoint:OCConnectionEndpointIDGraphDrivePermissions options:nil] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@/items/%@/permissions", driveID, fileID]];
	}

	if (shareID != nil)
	{
		permissionURL = [permissionURL URLByAppendingPathComponent:shareID];
	}

	return (permissionURL);
}

- (nullable NSProgress *)retrievePermissionsForDriveWithID:(OCDriveID)driveID item:(nullable OCItem *)item completionHandler:(OCConnectionShareRetrievalCompletionHandler)completionHandler
{
	OCLocation *location = [[OCLocation alloc] initWithBookmarkUUID:self.bookmark.uuid driveID:driveID path:item.path];
	NSURL *permissionURL = [self permissionsURLForDriveWithID:driveID fileID:(item.isRoot ? nil : item.fileID) permissionID:nil];

	return ([self requestODataAtURL:permissionURL requireSignals:[NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable] selectEntityID:nil selectProperties:nil filterString:nil parameters:nil entityClass:GAPermission.class options:@{
		OCODataOptionKeyLibreGraphDecoders: @[
			[[OCODataDecoder alloc] initWithLibreGraphID:@"@libre.graph.permissions.actions.allowedValues" entityClass:Nil customDecoder:^id(id  _Nonnull value, NSError * _Nullable __autoreleasing * _Nullable outError) { return (value); }],
			[[OCODataDecoder alloc] initWithLibreGraphID:@"@libre.graph.permissions.roles.allowedValues" entityClass:GAUnifiedRoleDefinition.class customDecoder:nil],
		],
		OCODataOptionKeyReturnODataResponse: @(YES),
		OCODataOptionKeyValueKey: @"value" // make sure that a response without any permissions in it (which may contain actions and roles, but no permissions) does not return a misinterpreted "nil" instance of GAPermission
	} completionHandler:^(NSError * _Nullable error, id  _Nullable response) {
		OCODataResponse *oDataResponse = OCTypedCast(response, OCODataResponse);

		NSArray<GAUnifiedRoleDefinition *> *gaRoleDefinitions = oDataResponse.libreGraphObjects[@"@libre.graph.permissions.roles.allowedValues"];

		NSMutableArray<OCShare *> *shares = [NSMutableArray new];
		for (GAPermission *gaPermission in oDataResponse.result) {
			[shares addObject:[OCShare shareFromGAPermission:gaPermission roleDefinitions:gaRoleDefinitions forLocation:location item:item category:OCShareCategoryByMe]];
		}

		NSMutableArray<OCShareRole *> *roles = nil;
		if (gaRoleDefinitions != nil)
		{
			roles = [NSMutableArray new];
			for (GAUnifiedRoleDefinition *gaRoleDefinition in gaRoleDefinitions) {
				OCShareRole *role;
				if ((role = gaRoleDefinition.role) != nil)
				{
					[roles addObject:gaRoleDefinition.role];
				}
			}
		}

		completionHandler(error, oDataResponse.libreGraphObjects[@"@libre.graph.permissions.actions.allowedValues"], roles, shares);
	}]);
}

@end

OCConnectionEndpointID OCConnectionEndpointIDGraphMeDrives = @"meDrives";
OCConnectionEndpointID OCConnectionEndpointIDGraphDrives = @"drives";
OCConnectionEndpointID OCConnectionEndpointIDGraphDrivePermissions = @"endpoint-graph-drive-permissions";
OCConnectionEndpointID OCConnectionEndpointIDGraphUsers = @"endpoint-graph-users";
OCConnectionEndpointID OCConnectionEndpointIDGraphGroups = @"endpoint-graph-groups";
