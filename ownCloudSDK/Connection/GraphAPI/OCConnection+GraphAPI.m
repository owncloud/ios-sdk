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
#import "GAUser.h"
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
#import "OCShareRole+GraphAPI.h"
#import "NSError+OCError.h"
#import "NSURL+OCURLQueryParameterExtensions.h"
#import "GAPermission.h"
#import "GAIdentity.h"

@implementation OCConnection (GraphAPI)

#pragma mark - User Info
- (nullable NSProgress *)retrieveLoggedInGraphUserWithCompletionHandler:(OCRetrieveLoggedInGraphUserCompletionHandler)completionHandler
{
	return ([self requestODataAtURL:[[self URLForEndpoint:OCConnectionEndpointIDGraphMe options:nil] urlByAppendingQueryParameters:@{ @"$expand" : @"memberOf" } replaceExisting:NO] requireSignals:[NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable] selectEntityID:nil selectProperties:nil filterString:nil parameters:nil entityClass:GAUser.class options:nil completionHandler:^(NSError * _Nullable error, id  _Nullable response) {
		OCUser *ocUser = nil;

		if (error == nil)
		{
			// Convert GAUser to OCUser
			if ([response isKindOfClass:GAUser.class])
			{
				ocUser = [OCUser userWithGraphUser:response];
			}
			else
			{
				error = OCError(OCErrorResponseUnknownFormat);
			}
		}

		completionHandler(error, ocUser);
	}]);
}

- (nullable NSProgress *)retrievePermissionsListForUser:(OCUser *)user withCompletionHandler:(OCRetrieveUserPermissionsCompletionHandler)completionHandler
{
	if (!self.useDriveAPI) {
		// Only available with Graph API
		completionHandler(OCError(OCErrorFeatureNotImplemented), nil);
		return (nil);
	}

	if (user.identifier == nil)
	{
		completionHandler(OCError(OCErrorInvalidParameter), nil);
		return(nil);
	}

	OCHTTPRequest *request;
	NSProgress *progress = nil;

	request = [OCHTTPRequest requestWithURL:[self URLForEndpoint:OCConnectionEndpointIDPermissionsList options:nil]];
	request.method = OCHTTPMethodPOST;
	request.requiredSignals = [NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable];
	[request setBodyWithJSON:@{
		@"account_uuid" : user.identifier
	}];

	progress = [self sendRequest:request ephermalCompletionHandler:^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
		if (error != nil)
		{
			completionHandler(error, nil);
		}
		else
		{
			NSError *jsonError = nil;
			NSDictionary *permissionsInfoDict;
			NSArray<OCUserPermissionIdentifier> *permissionsArray = nil;

			if ((permissionsInfoDict = [response bodyConvertedDictionaryFromJSONWithError:&jsonError]) != nil)
			{
				permissionsArray = OCTypedCast(OCTypedCast(permissionsInfoDict, NSDictionary)[@"permissions"], NSArray);
			}

			if (permissionsArray != nil)
			{
				completionHandler(nil, [[OCUserPermissions alloc] initWith:permissionsArray]);
			}
			else
			{
				completionHandler((jsonError!=nil) ? jsonError : OCError(OCErrorResponseUnknownFormat), nil);
			}
		}
	}];

	return (progress);
}

#pragma mark - Drives
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

- (nullable NSProgress *)retrievePermissionsForLocation:(OCLocation *)inLocation completionHandler:(OCConnectionShareRetrievalCompletionHandler)completionHandler
{
	// Check if inLocation is complete for using this API
	if (!inLocation.isRoot && (inLocation.fileID == nil)) {
		completionHandler(OCErrorWithDescription(OCErrorInsufficientParameters, @"Non-root location is missing fileID"), nil, nil, nil);
		return(nil);
	}
	if (inLocation.driveID == nil) {
		completionHandler(OCErrorWithDescription(OCErrorInsufficientParameters, @"Location is missing driveID"), nil, nil, nil);
		return(nil);
	}

	// Retrieve permissions
	OCLocation *location = [inLocation copy];
	location.bookmarkUUID = self.bookmark.uuid;

	NSURL *permissionURL = [self permissionsURLForDriveWithID:inLocation.driveID fileID:(inLocation.isRoot ? nil : inLocation.fileID) permissionID:nil];

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
			[shares addObject:[OCShare shareFromGAPermission:gaPermission roleDefinitions:gaRoleDefinitions forLocation:location item:nil category:OCShareCategoryByMe]];
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

- (nullable NSArray<OCShareActionID> *)shareActionsForDrive:(OCDrive *)drive
{
	OCUser *loggedInUser = self.loggedInUser;
	OCUserID userIdentifier = loggedInUser.identifier;
	NSMutableSet<OCShareActionID> *shareActionsSet = [NSMutableSet new];

	for (GAPermission *permission in drive.permissions)
	{
		if ( ((userIdentifier != nil) && ([permission.grantedToV2.user.identifier isEqual:userIdentifier])) ||
		     ((loggedInUser.groupMemberships != nil) && (permission.grantedToV2.group.identifier != nil) && [loggedInUser.groupMemberships containsObject:permission.grantedToV2.group.identifier])
		   )
		{
			for (OCShareRoleID roleID in permission.roles)
			{
				OCShareRole *globalRole;

				if ((globalRole = [self globalShareRoleFor:roleID]) != nil)
				{
					if (globalRole.allowedActions != nil)
					{
						[shareActionsSet addObjectsFromArray:globalRole.allowedActions];
					}
				}
			}
		}
	}

	return ((shareActionsSet.count > 0) ? shareActionsSet.allObjects : nil);
}

#pragma mark - Share Rolees
- (NSArray<OCShareRole *> *)globalShareRoles
{
	@synchronized(_drivesByID)
	{
		return (_globalShareRoles);
	}
}

- (void)setGlobalShareRoles:(NSArray<OCShareRole *> *)globalShareRoles
{
	@synchronized(_drivesByID)
	{
		_globalShareRoles = globalShareRoles;
	}
}

- (OCShareRole *)globalShareRoleFor:(OCShareRoleID)roleID
{
	@synchronized(_drivesByID)
	{
		for (OCShareRole *role in _globalShareRoles)
		{
			if ([OCShareRole isRoleID:role.identifier equalTo:roleID])
			{
				return (role);
			}
		}
	}

	return (nil);
}

- (nullable NSProgress *)retrieveRoleDefinitionsWithCompletionHandler:(OCRetrieveRoleDefinitionsCompletionHandler)completionHandler; //!< Retrieves the global list of all role definitions from the server
{
	return ([self requestODataAtURL:[self URLForEndpoint:OCConnectionEndpointIDGraphRoleDefinitions options:nil] requireSignals:[NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable] selectEntityID:nil selectProperties:nil filterString:nil parameters:nil entityClass:GAUnifiedRoleDefinition.class options:nil completionHandler:^(NSError * _Nullable error, id  _Nullable response) {
		NSMutableArray<OCShareRole *> *ocShareRoles = nil;

		if (error == nil)
		{
			// Convert GADrives to OCDrives
			NSArray<GAUnifiedRoleDefinition *> *gaRoleDefinitions;

			if ((gaRoleDefinitions = OCTypedCast(response, NSArray)) != nil)
			{
				ocShareRoles = [NSMutableArray new];

				for (GAUnifiedRoleDefinition *roleDefinition in gaRoleDefinitions)
				{
					OCShareRole *ocShareRole;

					if ((ocShareRole = roleDefinition.role) != nil)
					{
						[ocShareRoles addObject:ocShareRole];
					}
				}

				if (ocShareRoles.count > 0)
				{
					self.globalShareRoles = ocShareRoles;
				}
			}
		}

		OCLogDebug(@"Roles response: drives=%@, error=%@", ocShareRoles, error);

		if (completionHandler != nil)
		{
			completionHandler(error, (ocShareRoles.count > 0) ? ocShareRoles : nil);
		}
	}]);
}

@end

OCConnectionEndpointID OCConnectionEndpointIDGraphMe = @"endpoint-graph-me";
OCConnectionEndpointID OCConnectionEndpointIDGraphMeDrives = @"meDrives";
OCConnectionEndpointID OCConnectionEndpointIDGraphDrives = @"drives";
OCConnectionEndpointID OCConnectionEndpointIDGraphDrivePermissions = @"endpoint-graph-drive-permissions";
OCConnectionEndpointID OCConnectionEndpointIDGraphRoleDefinitions = @"endpoint-graph-role-definitions";
OCConnectionEndpointID OCConnectionEndpointIDGraphUsers = @"endpoint-graph-users";
OCConnectionEndpointID OCConnectionEndpointIDGraphGroups = @"endpoint-graph-groups";
