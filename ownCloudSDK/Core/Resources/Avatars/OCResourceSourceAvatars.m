//
//  OCResourceSourceAvatars.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.02.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCResourceSourceAvatars.h"
#import "OCResourceRequestAvatar.h"
#import "OCCore.h"
#import "OCMacros.h"
#import "OCResourceImage.h"
#import "OCAvatar.h"
#import "OCConnection.h"
#import "NSError+OCError.h"

@interface OCResourceSourceAvatars ()
{
	NSMutableSet<OCUserIdentifier> *_forceRefreshedAvatars;
}
@end

@implementation OCResourceSourceAvatars

- (OCResourceType)type
{
	return (OCResourceTypeAvatar);
}

- (OCResourceSourceIdentifier)identifier
{
	return (OCResourceSourceIdentifierAvatar);
}

- (OCResourceSourcePriority)priorityForType:(OCResourceType)type
{
	return (OCResourceSourcePriorityRemote);
}

- (OCResourceQuality)qualityForRequest:(OCResourceRequest *)request
{
	if ([request isKindOfClass:OCResourceRequestAvatar.class] && [request.reference isKindOfClass:OCUser.class])
	{
		OCUser *user;

		if ((user = OCTypedCast(request.reference, OCUser)) != nil)
		{
			OCResourceImage *avatarImage;

			if ((avatarImage = OCTypedCast(request.resource, OCResourceImage)) != nil)
			{
				OCUserIdentifier userIdentifier;

				if ((userIdentifier = user.userIdentifier) != nil)
				{
					if (_forceRefreshedAvatars == nil)
					{
						_forceRefreshedAvatars = [NSMutableSet new];
					}

					if (![_forceRefreshedAvatars containsObject:userIdentifier])
					{
						// Return fake high quality to force refresh once per session
						[_forceRefreshedAvatars addObject:userIdentifier];

						return (OCResourceQualityHigh);
					}

					if ((avatarImage.timestamp != nil) &&
					    (-avatarImage.timestamp.timeIntervalSinceNow > (3600.0 * 12.0)))
					{
						// Avatar is more than 12 hours old -> force refresh by returning a fake high quality

						return (OCResourceQualityHigh);
					}
				}
			}

			return (OCResourceQualityNormal);
		}
	}

	return (OCResourceQualityNone);
}

- (void)provideResourceForRequest:(OCResourceRequest *)request resultHandler:(OCResourceSourceResultHandler)resultHandler
{
	OCResourceRequestAvatar *avatarRequest;
	OCUser *user;

	if (((avatarRequest = OCTypedCast(request, OCResourceRequestAvatar)) != nil) &&
	    ((user = OCTypedCast(avatarRequest.reference, OCUser)) != nil))
	{
		OCConnection *connection;

		if ((connection = self.core.connection) != nil)
		{
			// NSString *specID = item.thumbnailSpecID;
			NSProgress *progress = nil;
			OCResourceImage *avatarImageResource = [request.resource.type isEqual:OCResourceTypeAvatar] ? OCTypedCast(request.resource, OCResourceImage) : nil;
			OCFileETag existingETag = avatarImageResource.version;

			progress = [connection retrieveAvatarForUser:user existingETag:existingETag withSize:avatarRequest.maxPixelSize completionHandler:^(NSError * _Nullable error, BOOL unchanged, OCAvatar * _Nullable avatar) {
				if (error != nil)
				{
					if ([error isOCErrorWithCode:OCErrorResourceDoesNotExist] && (existingETag == nil))
					{
						// Clear OCErrorResourceDoesNotExist if there was no previous version of the resource
						error = nil;
					}

					resultHandler(error, nil);
				}
				else if (unchanged && (existingETag != nil))
				{
					// Return a nil error and update existing avatar timestamp if the avatar has not changed
					avatarImageResource.timestamp = [NSDate new];

					resultHandler(nil, avatarImageResource);
				}
				else
				{
					OCResourceImage *resource = [[OCResourceImage alloc] initWithRequest:request];

					// Map avatar to corresponding resource fields
					resource.identifier = avatar.userIdentifier;
					resource.version = avatar.eTag;
					resource.quality = OCResourceQualityNormal;

					// Transfer avatar properties / data to resource
					resource.maxPixelSize = avatar.maxPixelSize;
					resource.data = avatar.data;

					resource.timestamp = avatar.timestamp;

					resource.image = avatar;

					resultHandler(nil, resource);
				}
			}];

			request.job.cancellationHandler = ^{
				[progress cancel];
			};

			return;
		}
	}

	resultHandler(OCError(OCErrorInsufficientParameters), nil);
}

@end

OCResourceSourceIdentifier OCResourceSourceIdentifierAvatar = @"core.avatar";
