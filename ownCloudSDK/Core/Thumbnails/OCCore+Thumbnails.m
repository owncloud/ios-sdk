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

@implementation OCCore (Thumbnails)

#pragma mark - Thumbnail support
+ (BOOL)thumbnailSupportedForMIMEType:(NSString *)mimeType
{
	static dispatch_once_t onceToken;
	static NSArray <NSString *> *supportedPrefixes;
	static BOOL loadThumbnailsForAll=NO, loadThumbnailsForNone=NO;

	dispatch_once(&onceToken, ^{
		supportedPrefixes = [[[OCClassSettings sharedSettings] settingsForClass:[OCCore class]] objectForKey:OCCoreThumbnailAvailableForMIMETypePrefixes];

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
	NSProgress *progress = [NSProgress indeterminateProgress];
	OCFileID fileID = item.fileID;
	OCItemVersionIdentifier *versionIdentifier = item.itemVersionIdentifier;
	NSString *specID = item.thumbnailSpecID;
	NSArray *thumbnailRequestTags = nil;
	NSString *thumbnailRequestUUID = [NSString stringWithFormat:@"%p", retrieveHandler];
	CGSize requestedMaximumSizeInPixels;

	retrieveHandler = [retrieveHandler copy];

	if (scale == 0)
	{
		scale = UIScreen.mainScreen.scale;
	}

	requestedMaximumSizeInPixels = CGSizeMake(floor(requestedMaximumSizeInPoints.width * scale), floor(requestedMaximumSizeInPoints.height * scale));

	progress.eventType = OCEventTypeRetrieveThumbnail;
	progress.localizedDescription = OCLocalizedString(@"Retrieving thumbnail…", @"");

	OCTLogDebug((thumbnailRequestTags = @[OCLogTagTypedID(@"ThumbnailRequest", thumbnailRequestUUID)]), @"Starting retrieval of thumbnail for %@, maximumSize:%@ scale:%f", item, NSStringFromCGSize(requestedMaximumSizeInPoints), scale);

	if (fileID != nil)
	{
		[self queueBlock:^{
			OCItemThumbnail *thumbnail;
			BOOL requestThumbnail = YES;

			// Is there a thumbnail for this file in the cache?
			if ((thumbnail = [self->_thumbnailCache objectForKey:item.fileID]) != nil)
			{
				// Yes! But is it the version we want?
				if ([thumbnail.itemVersionIdentifier isEqual:item.itemVersionIdentifier] && [thumbnail.specID isEqual:item.thumbnailSpecID])
				{
					// Yes it is!
					if ([thumbnail canProvideForMaximumSizeInPixels:requestedMaximumSizeInPixels])
					{
						// The size is fine, too!
						OCTLogDebug(thumbnailRequestTags, @"Providing final thumbnail from cache: %@", thumbnail);

						retrieveHandler(nil, self, item, thumbnail, NO, progress);

						requestThumbnail = NO;
					}
					else
					{
						// The size isn't sufficient
						retrieveHandler(nil, self, item, thumbnail, YES, progress);

						OCTLogDebug(thumbnailRequestTags, @"Returning smaller-sized thumbnail %@ as preview", thumbnail);
					}
				}
				else
				{
					// No it's not => remove outdated version from cache
					OCTLogDebug(thumbnailRequestTags, @"Removing outdated/different thumbnail from cache: item=(%@, %@), thumbnail=(%@, %@)", thumbnail, item.itemVersionIdentifier, item.thumbnailSpecID, thumbnail.itemVersionIdentifier, thumbnail.specID);

					[self->_thumbnailCache removeObjectForKey:item.fileID];

					thumbnail = nil;
				}
			}

			// Should a thumbnail be requested?
			if (requestThumbnail)
			{
				OCTLogDebug(thumbnailRequestTags, @"Starting thumbnail request");

				if (!progress.cancelled)
				{
					// Thumbnail database
					OCTLogDebug(thumbnailRequestTags, @"Starting thumbnail database request for version=%@, specID=%@, maximumSizeInPixels=%@", versionIdentifier, specID, NSStringFromCGSize(requestedMaximumSizeInPixels));

					[self.vault.database retrieveThumbnailDataForItemVersion:versionIdentifier specID:specID maximumSizeInPixels:requestedMaximumSizeInPixels completionHandler:^(OCDatabase *db, NSError *error, CGSize maxSize, NSString *mimeType, NSData *thumbnailData) {
						OCItemThumbnail *cachedThumbnail = nil;

						if (thumbnailData != nil)
						{
							// Create OCItemThumbnail from data returned from database
							OCItemThumbnail *cachedThumbnail = [OCItemThumbnail new];

							cachedThumbnail.maximumSizeInPixels = maxSize;
							cachedThumbnail.mimeType = mimeType;
							cachedThumbnail.data = thumbnailData;
							cachedThumbnail.specID = specID;
							cachedThumbnail.itemVersionIdentifier = versionIdentifier;

							OCTLogDebug(thumbnailRequestTags, @"Retrieved thumbnail from database: %@", cachedThumbnail);

							if ([cachedThumbnail canProvideForMaximumSizeInPixels:requestedMaximumSizeInPixels])
							{
								[self queueBlock:^{
									OCTLogDebug(thumbnailRequestTags, @"Providing final thumbnail from database: %@", cachedThumbnail);

									[self->_thumbnailCache setObject:cachedThumbnail forKey:fileID cost:(maxSize.width * maxSize.height * 4)];
									retrieveHandler(nil, self, item, cachedThumbnail, NO, progress);
								}];

								return;
							}
							else
							{
								OCTLogDebug(thumbnailRequestTags, @"Size of retrieved thumbnail from database does not match requested size: %@", cachedThumbnail);
							}
						}
						else
						{
							OCTLogDebug(thumbnailRequestTags, @"No matching thumbnail found in database", cachedThumbnail);
						}

						// Update the retrieveHandler with a thumbnail if it doesn't already have one
						if ((thumbnail == nil) && (cachedThumbnail != nil))
						{
							OCTLogDebug(thumbnailRequestTags, @"Returning preview thumbnail from database: %@", cachedThumbnail);
							retrieveHandler(nil, self, item, cachedThumbnail, YES, progress);
						}

						// Request a thumbnail from the server if the operation hasn't been cancelled yet.
						if (!progress.cancelled)
						{
							NSString *requestID = [NSString stringWithFormat:@"%@:%@-%@-%fx%f", versionIdentifier.fileID, versionIdentifier.eTag, specID, requestedMaximumSizeInPixels.width, requestedMaximumSizeInPixels.height];

							[self queueBlock:^{
								BOOL sendRequest = YES;

								// Queue retrieve handlers
								NSMutableArray <OCCoreThumbnailRetrieveHandler> *retrieveHandlersQueue;

								if ((retrieveHandlersQueue = self->_pendingThumbnailRequests[requestID]) == nil)
								{
									retrieveHandlersQueue = [NSMutableArray new];

									self->_pendingThumbnailRequests[requestID] = retrieveHandlersQueue;

									OCTLogDebug(thumbnailRequestTags, @"Creating request queue for thumbnail for %@", item.path);
								}

								if (retrieveHandlersQueue.count != 0)
								{
									// Another request is already pending
									sendRequest = NO;

									OCTLogDebug(thumbnailRequestTags, @"Another thumbnail request is already running for %@, enqueueing this request", item.path);
								}

								[retrieveHandlersQueue addObject:retrieveHandler];

								if (sendRequest)
								{
									OCEventTarget *target;
									NSProgress *retrieveProgress;

									OCTLogDebug(thumbnailRequestTags, @"Requesting thumbnail for %@ from server", item.path);

									// Define result event target
									target = [OCEventTarget eventTargetWithEventHandlerIdentifier:self.eventHandlerIdentifier userInfo:@{
										@"requestedMaximumSize" : [NSValue valueWithCGSize:requestedMaximumSizeInPixels],
										@"scale" : @(scale),
										OCEventUserInfoKeyItemVersionIdentifier : item.itemVersionIdentifier,
										@"specID" : item.thumbnailSpecID,
										OCEventUserInfoKeyItem : item,
									} ephermalUserInfo:@{
										@"requestID" : requestID
									}];

									// Request thumbnail from connection
									retrieveProgress = [self.connection retrieveThumbnailFor:item to:nil maximumSize:requestedMaximumSizeInPixels resultTarget:target];

									if (retrieveProgress != nil)
									{
										[progress addChild:retrieveProgress withPendingUnitCount:0];
									}
								}
							}];
						}
						else
						{
							OCTLogDebug(thumbnailRequestTags, @"Thumbnail retrieval has been cancelled (1)");

							if (retrieveHandler != nil)
							{
								retrieveHandler(OCError(OCErrorRequestCancelled), self, item, nil, NO, progress);
							}
						}
					}];
				}
				else
				{
					OCTLogDebug(thumbnailRequestTags, @"Thumbnail retrieval has been cancelled (2)");

					if (retrieveHandler != nil)
					{
						retrieveHandler(OCError(OCErrorRequestCancelled), self, item, nil, NO, progress);
					}
				}
			}
		}];
	}

	return(progress);
}

@end

@implementation OCCore (ThumbnailInternals)

- (void)_handleRetrieveThumbnailEvent:(OCEvent *)event sender:(id)sender
{
	[self queueBlock:^{
		OCItemThumbnail *thumbnail = event.result;
		// CGSize requestedMaximumSize = ((NSValue *)event.userInfo[@"requestedMaximumSize"]).CGSizeValue;
		// CGFloat scale = ((NSNumber *)event.userInfo[@"scale"]).doubleValue;
		OCItemVersionIdentifier *itemVersionIdentifier = OCTypedCast(event.userInfo[OCEventUserInfoKeyItemVersionIdentifier], OCItemVersionIdentifier);
		OCItem *item = OCTypedCast(event.userInfo[OCEventUserInfoKeyItem], OCItem);
		NSString *specID = OCTypedCast(event.userInfo[@"specID"], NSString);
		NSString *requestID = OCTypedCast(event.ephermalUserInfo[@"requestID"], NSString);

		OCLogDebug(@"Received thumbnail from server for %@, specID=%@, requestID=%@", item.path, specID, requestID);

		if ((event.error == nil) && (event.result != nil))
		{
			// Update cache
			OCLogDebug(@"Updating thumbnail cache with %@", thumbnail);
			[self->_thumbnailCache setObject:thumbnail forKey:itemVersionIdentifier.fileID];

			// Store in database
			OCLogDebug(@"Updating database with %@", thumbnail);
			[self.vault.database storeThumbnailData:thumbnail.data withMIMEType:thumbnail.mimeType specID:specID forItemVersion:itemVersionIdentifier maximumSizeInPixels:thumbnail.maximumSizeInPixels completionHandler:nil];
		}

		// Call all retrieveHandlers
		if (requestID != nil)
		{
			NSMutableArray <OCCoreThumbnailRetrieveHandler> *retrieveHandlersQueue = self->_pendingThumbnailRequests[requestID];

			if (retrieveHandlersQueue != nil)
			{
				[self->_pendingThumbnailRequests removeObjectForKey:requestID];
			}

			item.thumbnail = thumbnail;

			dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
				for (OCCoreThumbnailRetrieveHandler retrieveHandler in retrieveHandlersQueue)
				{
					NSString *thumbnailRequestUUID = [NSString stringWithFormat:@"%p", retrieveHandler];
					OCTLogDebug(@[OCLogTagTypedID(@"ThumbnailRequest", thumbnailRequestUUID)], @"Providing final thumbnail from server: %@", thumbnail);
					retrieveHandler(event.error, self, item, thumbnail, NO, nil);
				}
			});
		}
		else
		{
			OCLogDebug(@"Can't handle thumbnail response because of missing requestID");
		}
	}];
}

@end
