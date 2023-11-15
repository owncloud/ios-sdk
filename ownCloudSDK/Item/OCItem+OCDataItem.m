//
//  OCItem+OCDataItem.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 14.04.22.
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

#import "OCItem+OCDataItem.h"

@implementation OCItem (DataItem)

- (OCDataItemType)dataItemType
{
	return (OCDataItemTypeItem);
}

- (OCDataItemReference)dataItemReference
{
	return (self.localID);
}

- (OCDataItemVersion)dataItemVersion
{
	return (@(_versionSeed ^ ((self.syncActivity << 8) | self.cloudStatus)));
}

#pragma mark - OCDataConverter for OCDrives
+ (void)load
{
	OCDataConverter *itemToPresentableConverter;

	itemToPresentableConverter = [[OCDataConverter alloc] initWithInputType:OCDataItemTypeItem outputType:OCDataItemTypePresentable conversion:^id _Nullable(OCDataConverter * _Nonnull converter, OCItem * _Nullable inItem, OCDataRenderer * _Nullable renderer, NSError * _Nullable __autoreleasing * _Nullable outError, OCDataViewOptions  _Nullable options) {
		OCDataItemPresentable *presentable = nil;
//		__weak OCCore *weakCore = options[OCDataViewOptionCore];

		if (inItem != nil)
		{
			presentable = [[OCDataItemPresentable alloc] initWithItem:inItem];
			presentable.title = inItem.name;
			presentable.subtitle = (inItem.type == OCItemTypeCollection) ? @"folder" : [NSString stringWithFormat:@"file (%ld bytes)", (long)inItem.size];

//			presentable.availableResources = (imageDriveItem != nil) ?
//								((readmeDriveItem != nil) ? 	@[OCDataItemPresentableResourceCoverImage, OCDataItemPresentableResourceCoverDescription] :
//												@[OCDataItemPresentableResourceCoverImage]) :
//								((readmeDriveItem != nil) ? 	@[OCDataItemPresentableResourceCoverDescription] :
//												nil);
//
//			presentable.resourceRequestProvider = ^OCResourceRequest * _Nullable(OCDataItemPresentable * _Nonnull presentable, OCDataItemPresentableResource  _Nonnull presentableResource, OCDataViewOptions  _Nullable options, NSError * _Nullable __autoreleasing * _Nullable outError) {
//				OCResourceRequestDriveItem *resourceRequest = nil;
//
//				if ([presentableResource isEqual:OCDataItemPresentableResourceCoverImage] && (imageDriveItem != nil))
//				{
//					resourceRequest = [OCResourceRequestDriveItem requestDriveItem:imageDriveItem waitForConnectivity:YES changeHandler:nil];
//				}
//
//				if ([presentableResource isEqual:OCDataItemPresentableResourceCoverDescription] && (readmeDriveItem != nil))
//				{
//					resourceRequest = [OCResourceRequestDriveItem requestDriveItem:readmeDriveItem waitForConnectivity:YES changeHandler:nil];
//				}
//
//				resourceRequest.lifetime = OCResourceRequestLifetimeSingleRun;
//				resourceRequest.core = weakCore;
//
//				return (resourceRequest);
//			};
		}

		return (presentable);
	}];

	[OCDataRenderer.defaultRenderer addConverters:@[
		itemToPresentableConverter
	]];
}

@end
