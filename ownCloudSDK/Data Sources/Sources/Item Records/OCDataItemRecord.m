//
//  OCDataItemRecord.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.03.22.
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

#import "OCDataItemRecord.h"
#import "OCDataSource.h"

@implementation OCDataItemRecord

- (instancetype)initWithSource:(nullable OCDataSource *)source itemType:(OCDataItemType)type itemReference:(OCDataItemReference)itemRef hasChildren:(BOOL)hasChildren item:(nullable id<OCDataItem>)item
{
	if ((self = [super init]) != nil)
	{
		_source = source;

		_type = type;
		_reference = itemRef;

		_hasChildren = hasChildren;

		_item = item;
	}

	return (self);
}

- (instancetype)initWithSource:(nullable OCDataSource *)source item:(nullable id<OCDataItem>)item hasChildren:(BOOL)hasChildren
{
	return ([self initWithSource:source itemType:item.dataItemType itemReference:item.dataItemReference hasChildren:hasChildren item:item]);
}

- (void)retrieveItemWithCompletionHandler:(void (^)(NSError * _Nullable, OCDataItemRecord * _Nullable))completionHandler
{
	OCDataSource *strongSource;

	if (_item != nil)
	{
		completionHandler(nil, self);
		return;
	}

	if ((strongSource = _source) != nil)
	{
		[strongSource retrieveItemForRef:_reference reusingRecord:self completionHandler:^(NSError * _Nullable error, OCDataItemRecord * _Nullable record) {
			if (completionHandler != nil)
			{
				completionHandler(error, record);
			}
		}];
	}
}

@end
