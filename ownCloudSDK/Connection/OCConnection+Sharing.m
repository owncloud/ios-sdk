//
//  OCConnection+Sharing.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 01.03.19.
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

/*
	References:
	- Developer documentation: https://doc.owncloud.com/server/developer_manual/core/ocs-share-api.html
	- Implementation: https://github.com/owncloud/core/blob/master/apps/files_sharing/lib/Controller/Share20OcsController.php
*/

#import "OCConnection.h"
#import "OCItem.h"
#import "NSError+OCError.h"
#import "OCXMLParser.h"
#import "OCXMLParserNode.h"
#import "OCShare+OCXMLObjectCreation.h"
#import "OCLogger.h"
#import "NSDate+OCDateParser.h"
#import "NSProgress+OCEvent.h"
#import "OCMacros.h"
#import "NSProgress+OCExtensions.h"
#import "OCHTTPResponse+DAVError.h"
#import "OCHTTPDAVRequest.h"
#import "NSString+OCPath.h"
#import "NSURL+OCPrivateLink.h"
#import "NSError+OCNetworkFailure.h"
#import "OCConnection+GraphAPI.h"
#import "OCConnection+SharingLegacy.h"
#import "GADriveItemInvite.h"
#import "GADriveItemCreateLink.h"
#import "OCIdentity+GraphAPI.h"
#import "OCSharePermission.h"
#import "OCConnection+OData.h"
#import "OCShare+GraphAPI.h"
#import "GASharingLink.h"
#import "GASharingLinkPassword.h"

@implementation OCConnection (Sharing)

#pragma mark - Retrieval
- (nullable NSProgress *)retrieveSharesWithScope:(OCShareScope)scope forItem:(nullable OCItem *)item options:(nullable NSDictionary *)options completionHandler:(OCConnectionShareRetrievalCompletionHandler)completionHandler
{
	if (self.useDriveAPI)
	{
		if ((item != nil) && ((scope == OCShareScopeItem) || (scope == OCShareScopeItemWithReshares)))
		{
			return [self retrievePermissionsForLocation:item.location completionHandler:^(NSError * _Nullable error, NSArray<OCShareActionID> * _Nullable allowedPermissionActions, NSArray<OCShareRole *> * _Nullable roles, NSArray<OCShare *> * _Nullable shares) {
				completionHandler(error, allowedPermissionActions, roles, shares);
			}];
		}
	}

	OCHTTPRequest *request;
	NSProgress *progress = nil;
	NSURL *url = [self URLForEndpoint:OCConnectionEndpointIDShares options:nil];
	OCShareCategory shareCategory = OCShareCategoryUnknown;

	request = [OCHTTPRequest new];
	request.requiredSignals = self.propFindSignals;

	switch (scope)
	{
		case OCShareScopeItem:
		case OCShareScopeItemWithReshares:
		case OCShareScopeSubItems:
		break;

		default:
			if (item != nil)
			{
				OCLogWarning(@"item=%@ ignored for retrieval of shares with scope=%lu", item, scope);
			}
		break;
	}

	if ((item != nil) && self.useDriveAPI)
	{
		// Add the file ID to allow the server to determine the item's location (path, of course, isn't sufficient there)
		if (item.fileID != nil)
		{
			[request setValue:item.fileID forParameter:@"space_ref"];
		}
	}

	switch (scope)
	{
		case OCShareScopeSharedByUser:
			// No options to set
			shareCategory = OCShareCategoryByMe;
		break;

		case OCShareScopeSharedWithUser:
			shareCategory = OCShareCategoryWithMe;

			[request setValue:@"true" forParameter:@"shared_with_me"];
			[request setValue:@"all" forParameter:@"state"];
		break;

		case OCShareScopePendingCloudShares:
			shareCategory = OCShareCategoryWithMe;
			url = [[self URLForEndpoint:OCConnectionEndpointIDRemoteShares options:nil] URLByAppendingPathComponent:@"pending"];
		break;

		case OCShareScopeAcceptedCloudShares:
			shareCategory = OCShareCategoryWithMe;
			url = [self URLForEndpoint:OCConnectionEndpointIDRemoteShares options:nil];
		break;

		case OCShareScopeItem:
		case OCShareScopeItemWithReshares:
		case OCShareScopeSubItems:
			shareCategory = OCShareCategoryByMe;
			if (item == nil)
			{
				OCLogError(@"item required for retrieval of shares with scope=%lu", scope);

				if (completionHandler != nil)
				{
					completionHandler(OCError(OCErrorInsufficientParameters), nil, nil, nil);
				}

				return (nil);
			}

			[request setValue:item.path forParameter:@"path"];

			if (scope == OCShareScopeItemWithReshares)
			{
				[request setValue:@"true" forParameter:@"reshares"];
			}

			if (scope == OCShareScopeSubItems)
			{
				[request setValue:@"true" forParameter:@"subfiles"];
			}
		break;
	}

	request.url = url;

	progress = [self sendRequest:request ephermalCompletionHandler:^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
		OCSharingResponseStatus *status = nil;
		NSArray <OCShare *> *shares = nil;

		if (error == nil)
		{
			shares = [self _parseSharesResponse:response data:response.bodyData category:shareCategory error:&error status:&status statusErrorMapper:^NSError *(OCSharingResponseStatus *status) {
				NSError *error = nil;

				switch (status.statusCode.integerValue)
				{
					case 100:
					case 200:
						// Successful
					break;

					case 400:
						// Not a directory (fetching shares for directory)
						error = OCErrorWithDescription(OCErrorShareItemNotADirectory, status.message);
					break;

					case 404:
						switch (scope)
						{
							case OCShareScopeSharedByUser:
							case OCShareScopeSharedWithUser:
								// Couldn't fetch shares (fetching all shares)
								error = OCErrorWithDescription(OCErrorShareUnavailable, status.message);
							break;

							case OCShareScopeItem:
							case OCShareScopeItemWithReshares:
								// File doesn't exist (fetching shares for file)
								error = OCErrorWithDescription(OCErrorShareItemNotFound, status.message);
							break;

							default:
								// Unknown error
								error = status.error;
							break;
						}
					break;

					case 997:
						// Unauthorized
						error = OCErrorWithDescription(OCErrorShareUnauthorized, status.message);
					break;

					default:
						// Unknown error
						error = OCErrorWithDescription(OCErrorUnknown, status.message);
					break;
				}

				return (error);
			}];
		}

		completionHandler(error, nil, nil, (error == nil) ? shares : nil);
	}];

	return (progress);
}

- (nullable NSProgress *)retrieveShareWithID:(OCShareID)shareID options:(nullable NSDictionary *)options completionHandler:(OCConnectionShareCompletionHandler)completionHandler
{
	OCHTTPRequest *request;
	NSProgress *progress = nil;

	request = [OCHTTPRequest requestWithURL:[[self URLForEndpoint:OCConnectionEndpointIDShares options:nil] URLByAppendingPathComponent:shareID]];
	request.requiredSignals = self.propFindSignals;

	progress = [self sendRequest:request ephermalCompletionHandler:^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
		OCSharingResponseStatus *status = nil;
		NSArray <OCShare *> *shares = nil;

		if (!((response.error != nil) && ![response.error.domain isEqual:OCHTTPStatusErrorDomain]))
		{
			shares = [self _parseSharesResponse:response data:response.bodyData category:OCShareCategoryUnknown error:&error status:&status statusErrorMapper:^NSError *(OCSharingResponseStatus *status) {
					NSError *error = nil;

					switch (status.statusCode.integerValue)
					{
						case 100:
						case 200:
							// Successful
						break;

						case 404:
							// Share does not exist
							error = OCErrorWithDescription(OCErrorShareNotFound, status.message);
						break;

						default:
							// Unknown error
							error = status.error;
						break;
					}

					return (error);
				}];
		}

		completionHandler(error, (error == nil) ? shares.firstObject : nil);
	}];

	return (progress);
}

#pragma mark - Creation and deletion
- (nullable OCProgress *)createShare:(OCShare *)share options:(nullable OCShareOptions)options resultTarget:(OCEventTarget *)eventTarget
{
	// OC 10
	#if OC_LEGACY_SUPPORT
	if (!self.useDriveAPI) {
		return ([self legacyCreateShare:share options:options resultTarget:eventTarget]);
	}
	#endif /* OC_LEGACY_SUPPORT */

	NSProgress *progress = nil;

	// Check for required parameters in OCShare
	if ((share.itemLocation.driveID == nil) || (share.itemFileID == nil) || ((share.type != OCShareTypeLink) && (share.recipient == nil))) {
		[eventTarget handleError:OCError(OCErrorInsufficientParameters) type:OCEventTypeCreateShare uuid:nil sender:self];
		return (nil);
	}

	OCConnectionODataRequestCompletionHandler createCompletionHandler = ^(NSError * _Nullable error, id  _Nullable response) {
		NSLog(@"New share: %@ / %@", error, response);
		if (error != nil) {
			[eventTarget handleError:error type:OCEventTypeCreateShare uuid:nil sender:self];
		} else {
			GAPermission *permission;
			NSArray<GAPermission *> *permissions;
			if ((permissions = OCTypedCast(response, NSArray)) != nil)
			{
				permission = OCTypedCast(permissions.firstObject, GAPermission);
			}
			else
			{
				permission = OCTypedCast(response, GAPermission);
			}

			if (permission != nil)
			{
				OCShare *createdShare = [OCShare shareFromGAPermission:permission roleDefinitions:@[] forLocation:share.itemLocation item:nil category:OCShareCategoryByMe];
				if ([createdShare.firstRoleID isEqual:share.firstRoleID] && (share.firstRole != nil) && (createdShare.sharePermissions.count == 1))
				{
					// Reuse role of input share in case the created share uses the same role ID
					createdShare.sharePermissions = @[ [[OCSharePermission alloc] initWithRole:share.firstRole] ];
				}
				[eventTarget handleEvent:[OCEvent eventWithType:OCEventTypeCreateShare userInfo:nil ephermalUserInfo:nil result:createdShare] sender:self];
			}
			else
			{
				[eventTarget handleError:OCError(OCErrorInternal) type:OCEventTypeCreateShare uuid:nil sender:self];
			}
		}
	};

	if (share.type == OCShareTypeLink)
	{
		// Create link
		GADriveItemCreateLink *diCreateLink = [GADriveItemCreateLink new];
		if (share.protectedByPassword)
		{
			diCreateLink.password = share.password;
		}
		diCreateLink.expirationDateTime = share.expirationDate;
		diCreateLink.displayName = share.name;
		diCreateLink.type = share.firstRoleID;

		progress = [self createODataObject:diCreateLink atURL:[[self URLForEndpoint:OCConnectionEndpointIDGraphDrivePermissions options:nil] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@/items/%@/createLink",share.itemLocation.driveID,share.itemFileID]] requireSignals:[NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable] parameters:nil responseEntityClass:GAPermission.class completionHandler:createCompletionHandler];
	}
	else
	{
		// Share with user or group
		NSMutableArray<OCShareRoleID> *roles = [NSMutableArray new];
		NSMutableArray<OCShareActionID> *permissionActions = [NSMutableArray new];

		for (OCSharePermission *permission in share.sharePermissions)
		{
			if (permission.roleID != nil)
			{
				[roles addObject:permission.roleID];
			}
			if (permission.actions != nil)
			{
				[permissionActions addObjectsFromArray:permission.actions];
			}
		}

		GADriveItemInvite *diInvite = [GADriveItemInvite new];
		diInvite.recipients = @[ share.recipient.gaDriveRecipient ];
		diInvite.roles = (roles.count > 0) ? roles : nil;
		diInvite.libreGraphPermissionsActions = (permissionActions.count > 0) ? permissionActions : nil;
		diInvite.expirationDateTime = share.expirationDate;

		progress = [self createODataObject:diInvite atURL:[[self URLForEndpoint:OCConnectionEndpointIDGraphDrivePermissions options:nil] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@/items/%@/invite",share.itemLocation.driveID,share.itemFileID]] requireSignals:[NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable] parameters:nil responseEntityClass:GAPermission.class completionHandler:createCompletionHandler];
	}

	return (((progress != nil) ? [[OCProgress alloc] initRegisteredWithProgress:progress] : nil));
/*

	POST  https://ocis.ocis-web.master.owncloud.works/graph/v1beta1/drives/840ccb6b-bf3a-413b-a2c5-10594d3d1ede%24abe66e1c-1cb0-4bbd-be20-80f93771ef6a/items/840ccb6b-bf3a-413b-a2c5-10594d3d1ede%24abe66e1c-1cb0-4bbd-be20-80f93771ef6a!ea72f142-fd9d-4d4c-bb7a-fe3de3841539/invite
	{"roles":["b1e2218d-eef8-4d4c-b82d-0f1a1b48f3b5"],"recipients":[{"objectId":"058bff95-6708-4fe5-91e4-9ea3d377588b","@libre.graph.recipient.type":"user"}]}

{
    "value": [
        {
            "grantedToV2": {
                "user": {
                    "@libre.graph.userType": "Member",
                    "displayName": "Maurice Moss",
                    "id": "058bff95-6708-4fe5-91e4-9ea3d377588b"
                }
            },
            "id": "840ccb6b-bf3a-413b-a2c5-10594d3d1ede:abe66e1c-1cb0-4bbd-be20-80f93771ef6a:82efee4c-6840-4089-8a28-f017fb721899",
            "invitation": {
                "invitedBy": {
                    "user": {
                        "@libre.graph.userType": "Member",
                        "displayName": "Katherine Johnson",
                        "id": "534bb038-6f9d-4093-946f-133be61fa4e7"
                    }
                }
            },
            "roles": [
                "b1e2218d-eef8-4d4c-b82d-0f1a1b48f3b5"
            ]
        }
    ]
}
*/
}

- (nullable OCProgress *)updateShare:(OCShare *)share afterPerformingChanges:(void(^)(OCShare *share))performChanges resultTarget:(OCEventTarget *)eventTarget
{
	// OC 10
	#if OC_LEGACY_SUPPORT
	if (!self.useDriveAPI) {
		return ([self legacyUpdateShare:share afterPerformingChanges:performChanges resultTarget:eventTarget]);
	}
	#endif /* OC_LEGACY_SUPPORT */

	// Save previous values of editable properties
	NSString *previousName = share.name;
	NSString *previousPassword = share.password;
	BOOL previousProtectedByPassword = share.protectedByPassword;
	NSDate *previousExpirationDate = share.expirationDate;
	NSArray<OCShareRoleID> *previousRoleIDs = share.roleIDs;
	NSProgress *progress = nil;
	BOOL returnLinkShareOnlyError = NO;

	GAPermission *permissionUpdate = [GAPermission new];
	BOOL permissionUpdateContainsChanges = NO;
	NSString *newPassword = nil;
	BOOL newPasswordSet = NO;

	// Perform changes
	share = [share copy];
	performChanges(share);

	// Compare and detect changes
	if (OCNANotEqual(share.name, previousName))
	{
		if (share.type == OCShareTypeLink)
		{
			if (permissionUpdate.link == nil) {
				permissionUpdate.link = [GASharingLink new];
			}
			permissionUpdate.link.libreGraphDisplayName = (share.name != nil) ? share.name : GANull;
			permissionUpdateContainsChanges = YES;
		}
		else
		{
			returnLinkShareOnlyError = YES;
		}
	}

	if ((OCNANotEqual(share.password, previousPassword)) || (share.protectedByPassword != previousProtectedByPassword))
	{
		// Changing password requires extra request
		if (share.type == OCShareTypeLink)
		{
			if ((share.protectedByPassword != previousProtectedByPassword) && (previousProtectedByPassword))
			{
				// Remove password
				newPasswordSet = YES;
				newPassword = @""; // empty password => no password
			}
			else
			{
				// Set new password
				newPasswordSet = YES;
				newPassword = (share.password != nil) ? share.password : @"";
			}
		}
		else
		{
			returnLinkShareOnlyError = YES;
		}
	}

	if (OCNANotEqual(share.expirationDate, previousExpirationDate))
	{
		permissionUpdate.expirationDateTime = (share.expirationDate != nil) ? share.expirationDate : GANull;
		permissionUpdateContainsChanges = YES;
	}

	NSArray<OCShareRoleID> *roleIDs = share.roleIDs;
	if (OCNANotEqual(roleIDs, previousRoleIDs))
	{
		if (share.type == OCShareTypeLink)
		{
			if (permissionUpdate.link == nil) {
				permissionUpdate.link = [GASharingLink new];
			}
			permissionUpdate.link.type = roleIDs.firstObject;
		}
		else
		{
			permissionUpdate.roles = (roleIDs != nil) ? roleIDs : GANull;
		}
		permissionUpdateContainsChanges = YES;
	}

	if (returnLinkShareOnlyError)
	{
		[eventTarget handleError:OCErrorWithDescription(OCErrorFeatureNotSupportedByServer, @"Updating the name, password and expiryDate is only supported for shares of type link") type:OCEventTypeUpdateShare uuid:nil sender:self];
		return (nil);
	}

	if (!permissionUpdateContainsChanges && !newPasswordSet)
	{
		// No changes => return immediately
		[eventTarget handleEvent:[OCEvent eventForEventTarget:eventTarget type:OCEventTypeUpdateShare uuid:nil attributes:nil] sender:self];
		return (nil);
	}
	else
	{
		// Changes => schedule requests
		void(^handleResult)(NSError * _Nullable error, OCShare * _Nullable updatedShare) = ^(NSError * _Nullable error, OCShare * _Nullable updatedShare) {
			OCEvent *event = [OCEvent eventForEventTarget:eventTarget type:OCEventTypeUpdateShare uuid:nil attributes:nil];

			if (error != nil) {
				event.error = error;
			} else {
				if ([updatedShare.roleIDs isEqual:share.roleIDs]) {
					updatedShare.sharePermissions = share.sharePermissions;
				}
				event.result = updatedShare;
			}

			[eventTarget handleEvent:event sender:self];
		};

		if (newPasswordSet)
		{
			// Update password
			NSProgress *updateProgress = [self _updateShare:share password:newPassword completionHandler:^(NSError * _Nullable error, OCShare * _Nullable updatedShare) {
				if ((error == nil) && permissionUpdateContainsChanges)
				{
					// Update permission after that
					NSProgress *updateProgress = [self _updateShare:share withUpdate:permissionUpdate completionHandler:handleResult];
					[progress addChild:updateProgress withPendingUnitCount:100];
				}
				else
				{
					// Done, return result
					handleResult(error, share);
				}
			}];
			[progress addChild:updateProgress withPendingUnitCount:100];
		}
		else if (permissionUpdateContainsChanges)
		{
			// Update permission
			NSProgress *updateProgress = [self _updateShare:share withUpdate:permissionUpdate completionHandler:handleResult];
			[progress addChild:updateProgress withPendingUnitCount:100];
		}
	}

	return (((progress != nil) ? [[OCProgress alloc] initRegisteredWithProgress:progress] : nil));
}

- (nullable NSProgress *)_updateShare:(OCShare *)share withUpdate:(GAPermission *)updatePermission completionHandler:(void(^)(NSError * _Nullable error, OCShare * _Nullable updatedShare))completionHandler
{
	// Reference: https://owncloud.dev/apis/http/graph/permissions/#updating-sharing-permission-post-drivesdrive-iditemsitem-idpermissionsperm-id
	NSURL *url = [self permissionsURLForDriveWithID:share.itemLocation.driveID fileID:share.itemFileID permissionID:share.identifier];

	return ([self updateODataObject:updatePermission atURL:url requireSignals:[NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable] parameters:nil responseEntityClass:GAPermission.class completionHandler:^(NSError * _Nullable error, id  _Nullable response) {
		NSLog(@"Updated share permission: %@", response);
		completionHandler(error, (response != nil) ? [OCShare shareFromGAPermission:response roleDefinitions:@[] forLocation:share.itemLocation item:nil category:OCShareCategoryByMe] : nil);
	}]);
}

- (nullable NSProgress *)_updateShare:(OCShare *)share password:(NSString *)newPassword completionHandler:(void(^)(NSError * _Nullable error, OCShare * _Nullable updatedShare))completionHandler
{
	// Reference: https://owncloud.dev/apis/http/graph/permissions/#set-password-of-permission-post-drivesdrive-iditemsitem-idpermissionsperm-idsetpassword
	NSURL *url = [[self permissionsURLForDriveWithID:share.itemLocation.driveID fileID:share.itemFileID permissionID:share.identifier] URLByAppendingPathComponent:@"setPassword"];

	GASharingLinkPassword *sharingLinkPassword = [GASharingLinkPassword new];
	sharingLinkPassword.password = newPassword;

	return ([self createODataObject:sharingLinkPassword atURL:url requireSignals:[NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable] parameters:nil responseEntityClass:GAPermission.class completionHandler:^(NSError * _Nullable error, id  _Nullable response) {
		NSLog(@"Updated share password: %@", response);
		completionHandler(error, (response != nil) ? [OCShare shareFromGAPermission:response roleDefinitions:@[] forLocation:share.itemLocation item:nil category:OCShareCategoryByMe] : nil);
	}]);
}

- (nullable OCProgress *)deleteShare:(OCShare *)share resultTarget:(OCEventTarget *)eventTarget
{
	OCHTTPRequest *request;
	OCProgress *requestProgress = nil;
	NSURL *url;
	SEL resultHandlerAction;

	if (share.identifier == nil)
	{
		[eventTarget handleError:OCError(OCErrorInsufficientParameters) type:OCEventTypeDeleteShare uuid:nil sender:self];
		return (nil);
	}

	if (self.useDriveAPI)
	{
		// ocis
		// via https://owncloud.dev/apis/http/graph/permissions/#deleting-permission-delete-drivesdrive-iditemsitem-idpermissionsperm-id
		url = [self permissionsURLForDriveWithID:share.itemLocation.driveID fileID:share.itemFileID permissionID:share.identifier];
		resultHandlerAction = @selector(_handleDeletePermissionResult:error:);
	}
	#if OC_LEGACY_SUPPORT
	else
	{
		// OC 10
		url = [[self URLForEndpoint:OCConnectionEndpointIDShares options:@{
			OCConnectionOptionDriveID : OCDriveIDWrap(share.itemLocation.driveID)
		}] URLByAppendingPathComponent:share.identifier];

		resultHandlerAction = @selector(_handleDeleteShareResult:error:);

		if (share.type == OCShareTypeRemote)
		{
			// Shares of type "remote" need to be declined to be deleted
			if (share.owner.isRemote)
			{
				// But only if the owner is remote (otherwise the share was created by the logged in user)
				return ([self makeDecisionOnShare:share accept:NO resultTarget:eventTarget]);
			}
		}
	}
	#endif /* OC_LEGACY_SUPPORT */

	request = [OCHTTPRequest requestWithURL:url];
	request.method = OCHTTPMethodDELETE;
	request.requiredSignals = self.propFindSignals;
	request.forceCertificateDecisionDelegation = YES;

	request.resultHandlerAction = resultHandlerAction;
	request.eventTarget = eventTarget;

	[self.commandPipeline enqueueRequest:request forPartitionID:self.partitionID];

	requestProgress = request.progress;
	requestProgress.progress.eventType = OCEventTypeDeleteShare;
	requestProgress.progress.localizedDescription = [NSString stringWithFormat:OCLocalizedString(@"Deleting share for %@…",nil), share.itemLocation.path.lastPathComponent];

	return (requestProgress);
}

#if OC_LEGACY_SUPPORT
- (void)_handleDeleteShareResult:(OCHTTPRequest *)request error:(NSError *)error
{
	OCEvent *event;

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeDeleteShare uuid:request.identifier attributes:nil]) != nil)
	{
		if (error.isNetworkFailureError)
		{
			event.error = OCErrorWithDescriptionFromError(OCErrorNotAvailableOffline, OCLocalizedString(@"Sharing requires an active connection.",nil), error);
		}
		else if ((request.error != nil) && ![request.error.domain isEqual:OCHTTPStatusErrorDomain])
		{
			event.error = request.error;
		}
		else
		{
			[self _parseSharesResponse:request.httpResponse data:request.httpResponse.bodyData category:OCShareCategoryByMe error:&error status:NULL statusErrorMapper:^NSError *(OCSharingResponseStatus *status) {
				NSError *error = nil;

				switch (status.statusCode.integerValue)
				{
					case 100:
					case 200:
						// Successful
					break;

					case 404:
						// Share couldn't be deleted
						error = OCErrorWithDescription(OCErrorShareNotFound, status.message);
					break;

					default:
						// Unknown error
						error = status.error;
					break;
				}

				return (error);
			}];

			event.error = error;
		}
	}

	if (event != nil)
	{
		[request.eventTarget handleEvent:event sender:self];
	}
}
#endif /* OC_LEGACY_SUPPORT */

- (void)_handleDeletePermissionResult:(OCHTTPRequest *)request error:(NSError *)error
{
	OCEvent *event;

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeDeleteShare uuid:request.identifier attributes:nil]) != nil)
	{
		if (error.isNetworkFailureError)
		{
			event.error = OCErrorWithDescriptionFromError(OCErrorNotAvailableOffline, OCLocalizedString(@"Sharing requires an active connection.",nil), error);
		}
		else if ((request.error != nil) && ![request.error.domain isEqual:OCHTTPStatusErrorDomain])
		{
			event.error = request.error;
		}
		else
		{
			switch (request.httpResponse.status.code)
			{
				case OCHTTPStatusCodeCONTINUE:
				case OCHTTPStatusCodeOK:
				case OCHTTPStatusCodeNO_CONTENT:
					// Successful
				break;

				case OCHTTPStatusCodeNOT_FOUND:
					// Share couldn't be deleted
					event.error = OCError(OCErrorShareNotFound);
				break;

				default:
					// Unknown error
					event.error = request.httpResponse.status.error;
				break;
			}
		}
	}

	if (event != nil)
	{
		[request.eventTarget handleEvent:event sender:self];
	}
}

#pragma mark - Federated share management
- (nullable OCProgress *)makeDecisionOnShare:(OCShare *)share accept:(BOOL)accept resultTarget:(OCEventTarget *)eventTarget
{
	OCHTTPRequest *request;
	OCProgress *requestProgress = nil;
	NSURL *endpointURL = nil;

	if (share.identifier == nil)
	{
		[eventTarget handleError:OCError(OCErrorInsufficientParameters) type:OCEventTypeDecideOnShare uuid:nil sender:self];
		return (nil);
	}

	switch (share.type)
	{
		case OCShareTypeUserShare:
		case OCShareTypeGroupShare:
			endpointURL = [self URLForEndpoint:OCConnectionEndpointIDShares options:@{
				OCConnectionOptionDriveID : OCDriveIDWrap(share.itemLocation.driveID)
			}];
		break;

		case OCShareTypeRemote:
			endpointURL = [self URLForEndpoint:OCConnectionEndpointIDRemoteShares options:@{
				OCConnectionOptionDriveID : OCDriveIDWrap(share.itemLocation.driveID)
			}];
		break;

		default: break;
	}

	if (endpointURL == nil)
	{
		[eventTarget handleError:OCError(OCErrorInsufficientParameters) type:OCEventTypeDecideOnShare uuid:nil sender:self];
		return (nil);
	}

	request = [OCHTTPRequest requestWithURL:[[endpointURL URLByAppendingPathComponent:@"pending"] URLByAppendingPathComponent:share.identifier]];
	request.method = (accept ? OCHTTPMethodPOST : OCHTTPMethodDELETE);
	request.requiredSignals = self.propFindSignals;

	[request setValue:share.identifier forParameter:@"share_id"];

	request.resultHandlerAction = @selector(_handleMakeDecisionOnShareResult:error:);
	request.eventTarget = eventTarget;

	request.forceCertificateDecisionDelegation = YES;

	[self.commandPipeline enqueueRequest:request forPartitionID:self.partitionID];

	requestProgress = request.progress;
	requestProgress.progress.eventType = OCEventTypeDecideOnShare;
	requestProgress.progress.localizedDescription = (accept ? OCLocalizedString(@"Accepting share…",nil) : OCLocalizedString(@"Rejecting share…",nil));

	return (requestProgress);
}

- (void)_handleMakeDecisionOnShareResult:(OCHTTPRequest *)request error:(NSError *)error
{
	OCEvent *event;

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeDecideOnShare uuid:request.identifier attributes:nil]) != nil)
	{
		if ((request.error != nil) && ![request.error.domain isEqual:OCHTTPStatusErrorDomain])
		{
			event.error = request.error;
		}
		else
		{
			[self _parseSharesResponse:request.httpResponse data:request.httpResponse.bodyData category:OCShareCategoryWithMe error:&error status:NULL statusErrorMapper:^NSError *(OCSharingResponseStatus *status) {
				NSError *error = nil;

				switch (status.statusCode.integerValue)
				{
					case 100:
					case 200:
						// Successful
					break;

					case 404:
						// Share doesn’t exist
						error = OCErrorWithDescription(OCErrorShareNotFound, status.message);
					break;

					default:
						// Unknown error
						error = status.error;
					break;
				}

				return (error);
			}];

			event.error = error;
		}
	}

	if (event != nil)
	{
		[request.eventTarget handleEvent:event sender:self];
	}
}

#pragma mark - Private Link
- (nullable NSProgress *)retrievePrivateLinkForItem:(OCItem *)item completionHandler:(void(^)(NSError * _Nullable error, NSURL * _Nullable privateLink))completionHandler
{
	if (item.privateLink != nil)
	{
		// Private link already known for item
		completionHandler(nil, item.privateLink);
		return ([NSProgress indeterminateProgress]);
	}
	else
	{
		// Private link needs to be retrieved from server
		NSProgress *progress = nil;
		NSURL *endpointURL;
		OCHTTPDAVRequest *davRequest;

		if ((endpointURL = [self URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:@{ OCConnectionEndpointURLOptionDriveID : OCDriveIDWrap(item.driveID) }]) == nil)
		{
			// WebDAV root could not be generated (likely due to lack of username)
			completionHandler(OCError(OCErrorInternal), nil);
			return (nil);
		}

		davRequest = [OCHTTPDAVRequest propfindRequestWithURL:[endpointURL URLByAppendingPathComponent:item.path] depth:0];
		davRequest.requiredSignals = self.propFindSignals;

		[davRequest.xmlRequestPropAttribute addChildren:@[
			[OCXMLNode elementWithName:@"oc:privatelink"]
		]];

		progress = [self sendRequest:davRequest ephermalCompletionHandler:^(OCHTTPRequest * _Nonnull request, OCHTTPResponse * _Nullable response, NSError * _Nullable error) {
			if ((error == nil) && (response.status.isSuccess))
			{
				NSArray <NSError *> *errors = nil;
				NSArray <OCItem *> *items = nil;

				if ((items = [((OCHTTPDAVRequest *)request) responseItemsForBasePath:endpointURL.path drives:nil reuseUsersByID:self->_usersByUserID driveID:nil withErrors:&errors]) != nil)
				{
					NSURL *privateLink;

					if ((privateLink = items.firstObject.privateLink) != nil)
					{
						item.privateLink = privateLink;

						completionHandler(nil, privateLink);
						return;
					}
				}
			}
			else
			{
				if (error == nil)
				{
					error = response.bodyParsedAsDAVError;
				}

				if (error == nil)
				{
					error = response.status.error;
				}
			}

			completionHandler(error, nil);
		}];

		return (progress);
	}
}

- (nullable NSProgress *)retrievePathForPrivateLink:(NSURL *)privateLink completionHandler:(void(^)(NSError * _Nullable error, OCLocation * _Nullable location))completionHandler
{
	NSProgress *progress = nil;
	OCPrivateLinkFileID privateFileID = nil;

	if ((privateFileID = privateLink.privateLinkFileID) != nil)
	{
		OCHTTPDAVRequest *davRequest;
		NSURL *endpointURL = [self URLForEndpoint:OCConnectionEndpointIDWebDAVMeta options:nil];

		davRequest = [OCHTTPDAVRequest propfindRequestWithURL:[endpointURL URLByAppendingPathComponent:privateFileID] depth:0];
		davRequest.requiredSignals = self.propFindSignals;

		[davRequest.xmlRequestPropAttribute addChildren:@[
			[OCXMLNode elementWithName:@"oc:meta-path-for-user"],
			// [OCXMLNode elementWithName:@"D:resourcetype"] // The value returned for D:resourcetype is not correct. OC server will return d:collection for files, too.
		]];

		__weak OCConnection *weakSelf = self;

		progress = [self sendRequest:davRequest ephermalCompletionHandler:^(OCHTTPRequest * _Nonnull request, OCHTTPResponse * _Nullable response, NSError * _Nullable error) {
			OCConnection *strongSelf = weakSelf;

			if (strongSelf == nil)
			{
				// End if connection object is gone
				error = OCError(OCErrorInternal);
			}

			if ((error == nil) && (response.status.isSuccess))
			{
				NSArray <NSError *> *errors = nil;
				NSArray <OCItem *> *items = nil;

				if ((items = [((OCHTTPDAVRequest *)request) responseItemsForBasePath:endpointURL.path drives:nil reuseUsersByID:self->_usersByUserID driveID:nil withErrors:&errors]) != nil)
				{
					OCLocation *location;

					if ((location = items.firstObject.location) != nil)
					{
						// OC Server will return "/Documents" for the documents folder => make sure to normalize the path to follow OCPath conventions in that case
						// The value of D:resourcetype is not correct when requested with the same (resolution) request. OC server will return d:collection for files, too.

						// Perform standard depth 0 PROPFIND on path to determine type
						[strongSelf retrieveItemListAtLocation:location depth:0 options:@{ OCConnectionOptionIsNonCriticalKey : @(YES) } completionHandler:^(NSError * _Nullable error, NSArray<OCItem *> * _Nullable items) {
							OCPath normalizedPath = nil;
							OCLocation *normalizedLocation = nil;

							if (error == nil)
							{
								OCItem *item;

								if ((item = items.firstObject) != nil)
								{
									switch (item.type)
									{
										case OCItemTypeFile:
											normalizedPath = location.path.normalizedFilePath;
										break;

										case OCItemTypeCollection:
											normalizedPath = location.path.normalizedDirectoryPath;
										break;

										default:
											normalizedPath = location.path;
										break;
									}
								}

								normalizedLocation = [[OCLocation alloc] initWithDriveID:location.driveID path:normalizedPath];
							}

							if ((error != nil) && [error.domain isEqual:OCHTTPStatusErrorDomain] && (error.code == OCHTTPStatusCodeNOT_FOUND))
							{
								error = OCError(OCErrorItemDestinationNotFound);
							}

							completionHandler(error, normalizedLocation);
						}];

						return;
					}
				}

				error = OCError(OCErrorPrivateLinkResolutionFailed);
			}
			else
			{
				if (error == nil)
				{
					error = response.bodyParsedAsDAVError;
				}

				if (error == nil)
				{
					error = response.status.error;
				}
			}

			completionHandler(error, nil);
		}];
	}
	else
	{
		// Private File ID couldn't be determined
		completionHandler(OCError(OCErrorPrivateLinkInvalidFormat), nil);
	}

	return (progress);
}

@end
