//
//  OCDataItemPresentable.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.03.22.
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

#import "OCDataItemPresentable.h"
#import "NSError+OCError.h"

@implementation OCDataItemPresentable

- (instancetype)init
{
	return (nil);
}

- (instancetype)initWithReference:(OCDataItemReference)reference originalDataItemType:(OCDataItemType)originalDataItemType version:(OCDataItemVersion)dataItemVersion
{
	if ((self = [super init]) != nil)
	{
		_dataItemReference = reference;
		_originalDataItemType = originalDataItemType;
		_dataItemVersion = dataItemVersion;
	}

	return (self);
}

- (instancetype)initWithItem:(id<OCDataItem>)item
{
	if ((self = [super init]) != nil)
	{
		_originalDataItemType = item.dataItemType;
		_dataItemReference = item.dataItemReference;

		if ([item conformsToProtocol:@protocol(OCDataItemVersion)])
		{
			_dataItemVersion = ((id<OCDataItemVersion>)item).dataItemVersion;
		}
	}

	return (self);
}

- (OCDataItemType)dataItemType
{
	return (OCDataItemTypePresentable);
}

- (void)requestResource:(OCDataItemPresentableResource)resource withOptions:(OCDataViewOptions)options completionHandler:(void(^)(NSError * _Nullable error, id _Nullable resource))completionHandler
{
	if (resource != nil)
	{
		OCDataItemPresentableResourceProvider provider;

		if ((provider = self.resourceProvider) != nil)
		{
			provider(self, resource, options, completionHandler);
			return;
		}
		else
		{
			// No resource provider - nothing to return
			completionHandler(nil, nil);
		}
	}
	else
	{
		// "resource" is required
		completionHandler(OCError(OCErrorInsufficientParameters), nil);
	}
}

- (BOOL)respondsToSelector:(SEL)selector
{
	if (selector == @selector(hasChildrenUsingSource:))
	{
		return (_hasChildrenProvider != nil);
	}

	if (selector == @selector(dataSourceForChildrenUsingSource:))
	{
		return (_childrenDataSourceProvider != nil);
	}

	return ([super respondsToSelector:selector]);
}

- (BOOL)hasChildrenUsingSource:(OCDataSource *)source
{
	if (_hasChildrenProvider != nil)
	{
		return (_hasChildrenProvider(source, self));
	}

	if (_childrenDataSourceProvider != nil)
	{
		return (YES);
	}

	return (NO);
}

- (nullable OCDataSource *)dataSourceForChildrenUsingSource:(OCDataSource *)source
{
	if (_childrenDataSourceProvider != nil)
	{
		return (_childrenDataSourceProvider(source, self));
	}

	return (nil);
}

@end
