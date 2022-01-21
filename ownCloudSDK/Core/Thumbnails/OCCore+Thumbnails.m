//
//  OCCore+Thumbnails.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 14.12.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2018, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCCore.h"
#import "OCMacros.h"
#import "OCCore+Internal.h"
#import "OCItem+OCThumbnail.h"
#import "NSError+OCError.h"
#import "NSProgress+OCExtensions.h"
#import "OCLogger.h"
#import "OCResourceImage.h"
#import "OCResourceRequestItemThumbnail.h"
#import "OCResourceManager.h"

@implementation OCCore (Thumbnails)

#pragma mark - Thumbnail support
+ (BOOL)thumbnailSupportedForMIMEType:(NSString *)mimeType
{
	static dispatch_once_t onceToken;
	static NSArray <NSString *> *supportedPrefixes;
	static BOOL loadThumbnailsForAll=NO, loadThumbnailsForNone=NO;

	dispatch_once(&onceToken, ^{
		supportedPrefixes = [self classSettingForOCClassSettingsKey:OCCoreThumbnailAvailableForMIMETypePrefixes];

		if (supportedPrefixes.count == 0)
		{
			loadThumbnailsForNone = YES;
		}
		else
		{
			if ([supportedPrefixes containsObject:@"*"])
			{
				loadThumbnailsForAll = YES;
			}
		}
	});

	if (loadThumbnailsForAll)  { return(YES); }
	if (loadThumbnailsForNone) { return(NO);  }

	for (NSString *prefix in supportedPrefixes)
	{
		if ([mimeType hasPrefix:prefix])
		{
			return (YES);
		}
	}

	return (NO);
}


#pragma mark - Command: Retrieve Thumbnail
- (nullable NSProgress *)retrieveThumbnailFor:(OCItem *)item maximumSize:(CGSize)requestedMaximumSizeInPoints scale:(CGFloat)scale retrieveHandler:(OCCoreThumbnailRetrieveHandler)retrieveHandler
{
	return ([self retrieveThumbnailFor:item maximumSize:requestedMaximumSizeInPoints scale:scale waitForConnectivity:YES retrieveHandler:retrieveHandler]);
}

- (nullable NSProgress *)retrieveThumbnailFor:(OCItem *)item maximumSize:(CGSize)requestedMaximumSizeInPoints scale:(CGFloat)scale waitForConnectivity:(BOOL)waitForConnectivity retrieveHandler:(OCCoreThumbnailRetrieveHandler)retrieveHandler
{
	OCResourceRequestItemThumbnail *itemThumbnailRequest = [OCResourceRequestItemThumbnail requestThumbnailFor:item maximumSize:requestedMaximumSizeInPoints scale:scale waitForConnectivity:waitForConnectivity changeHandler:^(OCResourceRequest * _Nonnull request, NSError * _Nullable error, BOOL isOngoing, OCResource * _Nullable previousResource, OCResource * _Nullable newResource) {
		retrieveHandler(error, self, item, OCTypedCast(newResource, OCResourceImage).thumbnail, isOngoing, nil);
	}];

	itemThumbnailRequest.lifetime = OCResourceRequestLifetimeSingleRun;

	[self.vault.resourceManager startRequest:itemThumbnailRequest];

	return (nil);
}

@end

