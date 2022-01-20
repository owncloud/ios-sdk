//
//  OCResourceSourceAvatarPlaceholders.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 19.01.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

#import "OCResourceSourceAvatarPlaceholders.h"
#import "OCResourceRequestAvatar.h"
#import "OCCore.h"
#import "OCMacros.h"
#import "OCResourceTextPlaceholder.h"
#import "OCAvatar.h"
#import "OCConnection.h"
#import "NSError+OCError.h"

@implementation OCResourceSourceAvatarPlaceholders

- (OCResourceType)type
{
	return (OCResourceTypeAvatar);
}

- (OCResourceSourceIdentifier)identifier
{
	return (OCResourceSourceIdentifierAvatarPlaceholder);
}

- (OCResourceSourcePriority)priorityForType:(OCResourceType)type
{
	return (OCResourceSourcePriorityLocalFallback);
}

- (OCResourceQuality)qualityForRequest:(OCResourceRequest *)request
{
	if ([request isKindOfClass:OCResourceRequestAvatar.class] && [request.reference isKindOfClass:OCUser.class])
	{
		OCUser *user;

		if ((user = OCTypedCast(request.reference, OCUser)) != nil)
		{
			return (OCResourceQualityFallback);
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
		OCResourceTextPlaceholder *resource = [[OCResourceTextPlaceholder alloc] initWithRequest:request];

		resource.quality = OCResourceQualityFallback;
		resource.text = user.localizedInitials;
		resource.timestamp = NSDate.date;

		resultHandler(nil, resource);

		return;
	}

	resultHandler(OCError(OCErrorInsufficientParameters), nil);
}

@end

OCResourceSourceIdentifier OCResourceSourceIdentifierAvatarPlaceholder = @"core.avatar.placeholder";
