//
//  OCItemPolicy+OCDataItem.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.12.22.
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

#import "OCItemPolicy+OCDataItem.h"
#import "OCDataConverter.h"
#import "OCDataRenderer.h"
#import "OCDataItemPresentable.h"
#import "OCSymbol.h"

@implementation OCItemPolicy (OCDataItem)

#pragma mark - OCDataItem & OCDataItemVersioning
- (OCDataItemType)dataItemType
{
	return (OCDataItemTypeItemPolicy);
}

- (OCDataItemReference)dataItemReference
{
	return ((self.uuid != nil) ? self.uuid : [NSString stringWithFormat:@"%@:%@:%p", self.kind, self.databaseID, self]);
}

- (OCDataItemVersion)dataItemVersion
{
	return ([NSString stringWithFormat:@"%@", self.location.string]);
}

#pragma mark - OCDataConverter for OCDrives
+ (void)load
{
	OCDataConverter *itemPolicyToPresentableConverter;

	itemPolicyToPresentableConverter = [[OCDataConverter alloc] initWithInputType:OCDataItemTypeItemPolicy outputType:OCDataItemTypePresentable conversion:^id _Nullable(OCDataConverter * _Nonnull converter, OCItemPolicy * _Nullable inPolicy, OCDataRenderer * _Nullable renderer, NSError * _Nullable __autoreleasing * _Nullable outError, OCDataViewOptions  _Nullable options) {
		OCDataItemPresentable *presentable = nil;

		if (inPolicy != nil)
		{
			presentable = [[OCDataItemPresentable alloc] initWithItem:inPolicy];
			presentable.title = inPolicy.location.lastPathComponent;
			presentable.subtitle = inPolicy.location.path;
			presentable.image = (inPolicy.location.type == OCLocationTypeFile) ? [OCSymbol iconForSymbolName:@"doc"] : [OCSymbol iconForSymbolName:@"folder"] ;
		}

		return (presentable);
	}];

	[OCDataRenderer.defaultRenderer addConverters:@[
		itemPolicyToPresentableConverter
	]];
}

@end
