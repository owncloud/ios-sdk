//
//  OCConnection+Recipients.m
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
#import "NSError+OCError.h"
#import "OCMacros.h"
#import "OCConnection+OData.h"
#import "OCConnection+GraphAPI.h"
#import "GAUser.h"
#import "GAGroup.h"
#import "NSProgress+OCExtensions.h"

#if OC_LEGACY_SUPPORT
#import "OCConnection+RecipientsLegacy.h"
#endif /* OC_LEGACY_SUPPORT */

@implementation OCConnection (Recipients)

#pragma mark - Search
- (nullable NSProgress *)retrieveRecipientsForItemType:(OCItemType)itemType ofShareType:(nullable NSArray <OCShareTypeID> *)shareTypes searchTerm:(nullable NSString *)searchTerm maximumNumberOfRecipients:(NSUInteger)maximumNumberOfRecipients completionHandler:(OCConnectionRecipientsRetrievalCompletionHandler)completionHandler
{
	NSProgress *progress = nil;

	// OC 10
	#if OC_LEGACY_SUPPORT
	if (!self.useDriveAPI) {
		return ([self legacyRetrieveRecipientsForItemType:itemType ofShareType:shareTypes searchTerm:searchTerm maximumNumberOfRecipients:maximumNumberOfRecipients completionHandler:completionHandler]);
	}
	#endif /* OC_LEGACY_SUPPORT */

	// ocis
	// Reference: https://owncloud.dev/apis/http/graph/users/#get-users
	if ((searchTerm != nil) && (searchTerm.length > 0))
	{
		NSProgress *combinedProgress = [NSProgress indeterminateProgress];
		NSMutableArray<OCIdentity *> *resultIdentities = [NSMutableArray new];
		__block NSError *combinedError = nil;
		dispatch_group_t completionGroup = dispatch_group_create();

		dispatch_group_enter(completionGroup);
		progress = [self _retrieveUsersForSearchTerm:searchTerm maximumResultCount:maximumNumberOfRecipients completionHandler:^(NSError * _Nullable error, NSArray<OCIdentity *> * _Nullable recipients, BOOL finished) {
			@synchronized(resultIdentities) {
				if (error != nil) {
					combinedError = error;
				}
				else
				{
					[resultIdentities addObjectsFromArray:recipients];
				}
			}
			dispatch_group_leave(completionGroup);
		}];
		[combinedProgress addChild:progress withPendingUnitCount:50];

		dispatch_group_enter(completionGroup);
		progress = [self _retrieveGroupsForSearchTerm:searchTerm maximumResultCount:maximumNumberOfRecipients completionHandler:^(NSError * _Nullable error, NSArray<OCIdentity *> * _Nullable recipients, BOOL finished) {
			@synchronized(resultIdentities) {
				if (error != nil) {
					combinedError = error;
				}
				else
				{
					[resultIdentities addObjectsFromArray:recipients];
				}
			}
			dispatch_group_leave(completionGroup);
		}];
		[combinedProgress addChild:progress withPendingUnitCount:50];

		dispatch_group_notify(completionGroup, dispatch_get_main_queue(), ^{
			completionHandler(combinedError, (combinedError == nil) ? resultIdentities : nil, YES);
		});
	}
	else
	{
		if (completionHandler != nil)
		{
			completionHandler(nil, @[], YES);
		}
	}

	return (progress);
}

- (nullable NSProgress *)_retrieveUsersForSearchTerm:(NSString *)searchTerm maximumResultCount:(NSUInteger)maximumResultCount completionHandler:(OCConnectionRecipientsRetrievalCompletionHandler)completionHandler
{
	return ([self requestODataAtURL:[self URLForEndpoint:OCConnectionEndpointIDGraphUsers options:nil] requireSignals:[NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable] selectEntityID:nil selectProperties:nil filterString:nil parameters:@{
		@"$search" : [NSString stringWithFormat:@"\"%@\"", searchTerm],
		@"$orderby" : @"displayName"
	} entityClass:GAUser.class completionHandler:^(NSError * _Nullable error, id  _Nullable response) {
		NSMutableArray<OCIdentity *> *ocIdentities = nil;

		if (error == nil)
		{
			// Convert GAUser to OCIdentities
			NSArray<GAUser *> *gaUsers;

			if ((gaUsers = OCTypedCast(response, NSArray)) != nil)
			{
				ocIdentities = [NSMutableArray new];

				for (GAUser *gaUser in gaUsers)
				{
					OCUser *ocUser;

					if ((ocUser = [OCUser userWithGraphUser:gaUser]) != nil)
					{
						OCIdentity *ocIdentity;

						if ((ocIdentity = [OCIdentity identityWithUser:ocUser]) != nil)
						{
							[ocIdentities addObject:ocIdentity];
						}
					}
				}
			}
		}

		OCLogDebug(@"User response: identities=%@, error=%@", ocIdentities, error);

		completionHandler(error, (ocIdentities.count > 0) ? ocIdentities : nil, YES);
	}]);
}

- (nullable NSProgress *)_retrieveGroupsForSearchTerm:(nullable NSString *)searchTerm maximumResultCount:(NSUInteger)maximumResultCount completionHandler:(OCConnectionRecipientsRetrievalCompletionHandler)completionHandler
{
	return ([self requestODataAtURL:[self URLForEndpoint:OCConnectionEndpointIDGraphGroups options:nil] requireSignals:[NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable] selectEntityID:nil selectProperties:nil filterString:nil parameters:@{
		@"$search" : [NSString stringWithFormat:@"\"%@\"", searchTerm],
		@"$orderby" : @"displayName"
	} entityClass:GAGroup.class completionHandler:^(NSError * _Nullable error, id  _Nullable response) {
		NSMutableArray<OCIdentity *> *ocIdentities = nil;

		if (error == nil)
		{
			// Convert GAGroup to OCIdentities
			NSArray<GAGroup *> *gaGroups;

			if ((gaGroups = OCTypedCast(response, NSArray)) != nil)
			{
				ocIdentities = [NSMutableArray new];

				for (GAGroup *gaGroup in gaGroups)
				{
					OCGroup *ocGroup;

					if ((ocGroup = [OCGroup groupWithGraphGroup:gaGroup]) != nil)
					{
						OCIdentity *ocIdentity;

						if ((ocIdentity = [OCIdentity identityWithGroup:ocGroup]) != nil)
						{
							[ocIdentities addObject:ocIdentity];
						}
					}
				}
			}
		}

		OCLogDebug(@"Group response: identities=%@, error=%@", ocIdentities, error);

		completionHandler(error, (ocIdentities.count > 0) ? ocIdentities : nil, YES);
	}]);
}

#pragma mark - Lookup
- (nullable NSProgress *)retrieveUserForID:(OCUserID)userID completionHandler:(OCConnectionUserRetrievalCompletionHandler)completionHandler
{
	// ocis-only
	if (!self.useDriveAPI) {
		completionHandler(OCError(OCErrorFeatureNotSupportedByServer), nil);
		return(nil);
	}

	// Reference: https://owncloud.dev/apis/http/graph/users/#get-usersuserid-or-accountname
	return ([self requestODataAtURL:[[self URLForEndpoint:OCConnectionEndpointIDGraphUsers options:nil] URLByAppendingPathComponent:userID] requireSignals:[NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable] selectEntityID:nil selectProperties:nil filterString:nil parameters:nil entityClass:GAUser.class completionHandler:^(NSError * _Nullable error, id  _Nullable response) {
		OCUser *user = nil;

		if (error == nil)
		{
			GAUser *gaUser;

			if ((gaUser = OCTypedCast(response, GAUser)) != nil)
			{
				// Convert GAUser to OCUser
				user = [OCUser userWithGraphUser:gaUser];
			}
			else
			{
				error = OCError(OCErrorResponseUnknownFormat);
			}
		}

		completionHandler(error, user);
	}]);
}

- (nullable NSProgress *)retrieveGroupForID:(OCGroupID)groupID completionHandler:(OCConnectionGroupRetrievalCompletionHandler)completionHandler
{
	// ocis-only
	if (!self.useDriveAPI) {
		completionHandler(OCError(OCErrorFeatureNotSupportedByServer), nil);
		return(nil);
	}

	// Reference: https://owncloud.dev/apis/http/graph/groups/#get-groupsgroupid
	return ([self requestODataAtURL:[[self URLForEndpoint:OCConnectionEndpointIDGraphGroups options:nil] URLByAppendingPathComponent:groupID] requireSignals:[NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable] selectEntityID:nil selectProperties:nil filterString:nil parameters:nil entityClass:GAGroup.class completionHandler:^(NSError * _Nullable error, id  _Nullable response) {
		OCGroup *group = nil;

		if (error == nil)
		{
			GAGroup *gaGroup;

			if ((gaGroup = OCTypedCast(response, GAGroup)) != nil)
			{
				// Convert GAGroup to OCGroup
				group = [OCGroup groupWithGraphGroup:gaGroup];
			}
			else
			{
				error = OCError(OCErrorResponseUnknownFormat);
			}
		}

		completionHandler(error, group);
	}]);
}

@end
