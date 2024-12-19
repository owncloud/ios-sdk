//
//  OCShare+OCDataItem.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 19.12.22.
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

#import "OCShare+OCDataItem.h"
#import "OCDataRenderer.h"
#import "OCDataConverter.h"
#import "OCDataItemPresentable.h"
#import "OCSharePermission.h"

@implementation OCShare (OCDataItem)

- (OCDataItemType)dataItemType
{
	return (OCDataItemTypeShare);
}

- (OCDataItemReference)dataItemReference
{
	return (self.identifier);
}

- (OCDataItemVersion)dataItemVersion
{
	NSArray<OCShare *> *otherItemShares = self.otherItemShares;
	NSString *otherItemSharesVersions = @"";

	if ((otherItemShares != nil) && (otherItemShares.count > 0))
	{
		for (OCShare *share in otherItemShares)
		{
			otherItemSharesVersions = [otherItemSharesVersions stringByAppendingString:(NSString *)share.dataItemVersion];
		}
	}

	return ([NSString stringWithFormat:@"%@%lx%@%@%@%d%@_%@%@%@%@", self.itemLocation.string, self.permissions, self.name, self.token, self.url, self.protectedByPassword, self.state, self.accepted, self.expirationDate, otherItemSharesVersions, self.sharePermissions.firstObject.roleID]);
}

#pragma mark - OCDataConverter for OCDrives
+ (void)load
{
	OCDataConverter *shareToPresentableConverter;

	shareToPresentableConverter = [[OCDataConverter alloc] initWithInputType:OCDataItemTypeShare outputType:OCDataItemTypePresentable conversion:^id _Nullable(OCDataConverter * _Nonnull converter, OCShare * _Nullable inShare, OCDataRenderer * _Nullable renderer, NSError * _Nullable __autoreleasing * _Nullable outError, OCDataViewOptions  _Nullable options) {
		OCDataItemPresentable *presentable = nil;

		if (inShare != nil)
		{
			presentable = [[OCDataItemPresentable alloc] initWithItem:inShare];
			presentable.title = inShare.itemLocation.path;
			presentable.subtitle = inShare.owner.displayName;
		}

		return (presentable);
	}];

	[OCDataRenderer.defaultRenderer addConverters:@[
		shareToPresentableConverter
	]];
}

@end
