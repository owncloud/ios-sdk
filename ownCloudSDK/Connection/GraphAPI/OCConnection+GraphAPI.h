//
//  OCConnection+GraphAPI.h
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

#import "OCConnection.h"
#import "GAUnifiedRoleDefinition.h"

NS_ASSUME_NONNULL_BEGIN

@class OCDrive;

typedef void(^OCRetrieveDriveListCompletionHandler)(NSError * _Nullable error, NSArray<OCDrive *> * _Nullable drives);
typedef void(^OCRetrieveLoggedInGraphUserCompletionHandler)(NSError * _Nullable error, OCUser * _Nullable user);
typedef void(^OCRetrieveRoleDefinitionsCompletionHandler)(NSError * _Nullable error, NSArray<OCShareRole *> * _Nullable shareRoles);

@interface OCConnection (GraphAPI)

#pragma mark - User Info
- (nullable NSProgress *)retrieveLoggedInGraphUserWithCompletionHandler:(OCRetrieveLoggedInGraphUserCompletionHandler)completionHandler;

#pragma mark - Drives
@property(strong,nullable,nonatomic) NSArray<OCDrive *> *drives; //!< Current list of known drives
@property(strong,nullable,nonatomic) NSArray<OCShareRole *> *globalShareRoles; //!< Global list of share roles

- (nullable OCDrive *)driveWithID:(OCDriveID)driveID; //!< Returns the OCDrive instance for the provided ID if it is already known locally
- (void)driveWithID:(OCDriveID)driveID completionHandler:(void(^)(OCDrive * _Nullable drive))completionHandler; //!< Returns the OCDrive instance for the provided ID. Will attempt to retrieve it from the server if not known locally.

- (nullable NSProgress *)retrieveDriveListWithCompletionHandler:(OCRetrieveDriveListCompletionHandler)completionHandler; //!< Retrieves a list of drives and updates .drives

#pragma mark - Permissions
- (NSURL *)permissionsURLForDriveWithID:(OCDriveID)driveID fileID:(nullable OCFileID)fileID permissionID:(nullable OCShareID)shareID; //!< Returns the API URL for the provided driveID [+ fileID [+ shareID]]

- (nullable NSProgress *)retrievePermissionsForLocation:(OCLocation *)location completionHandler:(OCConnectionShareRetrievalCompletionHandler)completionHandler; //!< Retrieves the permissions for a drive and returns them as OCShares. The original GAPermission objects remain available as OCShare.originGAPermission but should only be used for debugging. The passed location must contain a fileID when not querying a root path

- (nullable NSArray<OCShareActionID> *)shareActionsForDrive:(OCDrive *)drive; //!< Return all allowed share actions composed from the user's role(s) and group role(s) the user is a member of

#pragma mark - Share Rolees
- (nullable NSProgress *)retrieveRoleDefinitionsWithCompletionHandler:(nullable OCRetrieveRoleDefinitionsCompletionHandler)completionHandler; //!< Retrieves the global list of all role definitions from the server

@end

extern OCConnectionEndpointID OCConnectionEndpointIDGraphMe;
extern OCConnectionEndpointID OCConnectionEndpointIDGraphMeDrives;
extern OCConnectionEndpointID OCConnectionEndpointIDGraphDrives;
extern OCConnectionEndpointID OCConnectionEndpointIDGraphDrivePermissions;
extern OCConnectionEndpointID OCConnectionEndpointIDGraphRoleDefinitions;
extern OCConnectionEndpointID OCConnectionEndpointIDGraphUsers;
extern OCConnectionEndpointID OCConnectionEndpointIDGraphGroups;

NS_ASSUME_NONNULL_END
