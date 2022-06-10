//
//  OCDataSourceKVO.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 16.05.22.
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

#import "OCDataSourceKVO.h"
#import "OCDeallocAction.h"

@interface OCDataSourceKVO ()
{
	__weak NSObject *_object;
	NSString *_keyPath;

	BOOL _kvoRegistered;

	OCDataSourceKVOItemUpdateHandler _itemUpdateHandler;
	OCDataSourceKVOVersionedItemUpdateHandler _versionedItemUpdateHandler;
}

@end

@implementation OCDataSourceKVO

- (instancetype)initWithObject:(NSObject *)object keyPath:(NSString *)keyPath itemUpdateHandler:(OCDataSourceKVOItemUpdateHandler)itemUpdateHandler
{
	if ((self = [self initWithObject:object keyPath:keyPath]) != nil)
	{
		_itemUpdateHandler = [itemUpdateHandler copy];

		[self registerKVO];
	}

	return (self);
}

- (instancetype)initWithObject:(NSObject *)object keyPath:(NSString *)keyPath versionedItemUpdateHandler:(OCDataSourceKVOVersionedItemUpdateHandler)versionedItemUpdateHandler
{
	if ((self = [self initWithObject:object keyPath:keyPath]) != nil)
	{
		if (versionedItemUpdateHandler != nil)
		{
			_versionedItemUpdateHandler = [versionedItemUpdateHandler copy];
		}

		[self registerKVO];
	}

	return (self);
}

- (instancetype)initWithObject:(NSObject *)object keyPath:(NSString *)keyPath
{
	if ((self = [super init]) != nil)
	{
		_keyPath = keyPath;
		_object = object;
	}

	return (self);
}

- (void)dealloc
{
	[self unregisterKVO];
}

- (void)registerKVO
{
	__weak OCDataSourceKVO *weakSelf = self;

	if ((_object != nil) && (!_kvoRegistered))
	{
		[_object addObserver:self forKeyPath:_keyPath options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew context:(__bridge void *)self];
		_kvoRegistered = YES;

		[OCDeallocAction addAction:^{
			[weakSelf unregisterKVO];
		} forDeallocationOfObject:_object];
	}
}

- (void)unregisterKVO
{
	if (_kvoRegistered)
	{
		[_object removeObserver:self forKeyPath:_keyPath context:(__bridge void *)self];
		_kvoRegistered = NO;
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
	id newValue = change[NSKeyValueChangeNewKey];

	if ([newValue isKindOfClass:NSNull.class])
	{
		newValue = nil;
	}

	if (_itemUpdateHandler != nil)
	{
		NSSet<id<OCDataItem>> *updatedItems = nil;
		NSArray<id<OCDataItem>> *items;

		items = _itemUpdateHandler(object, keyPath, newValue, &updatedItems);

		[self setItems:items updated:updatedItems];
	}
	else if (_versionedItemUpdateHandler != nil)
	{
		NSArray<id<OCDataItem,OCDataItemVersioning>> *versionedItems;

		versionedItems = _versionedItemUpdateHandler(object, keyPath, newValue);

		[self setVersionedItems:versionedItems];
	}
	else
	{
		[self setVersionedItems:(NSArray<id<OCDataItem,OCDataItemVersioning>> *)newValue];
	}
}

@end
