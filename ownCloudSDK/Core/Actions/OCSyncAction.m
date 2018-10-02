//
//  OCSyncAction.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.09.18.
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

#import "OCSyncAction.h"
#import <objc/runtime.h>

@implementation OCSyncAction

#pragma mark - Init
- (instancetype)initWithItem:(OCItem *)item
{
	if ((self = [self init]) != nil)
	{
		_localItem = item;
		_archivedServerItem = ((item.remoteItem != nil) ? item.remoteItem : item);
	}

	return (self);
}

#pragma mark - Implementation
- (BOOL)implements:(SEL)featureSelector
{
	IMP rootClassIMP = method_getImplementation(class_getInstanceMethod([OCSyncAction class], featureSelector));
	IMP selfClassIMP = method_getImplementation(class_getInstanceMethod([self class], featureSelector));

	if (rootClassIMP != selfClassIMP)
	{
		return (YES);
	}

	return (NO);
}

#pragma mark - Preflight and descheduling
- (void)preflightWithContext:(OCSyncContext *)syncContext
{
}

- (void)descheduleWithContext:(OCSyncContext *)syncContext
{
}

#pragma mark - Scheduling and result handling
- (BOOL)scheduleWithContext:(OCSyncContext *)syncContext
{
	return (YES);
}

- (BOOL)handleResultWithContext:(OCSyncContext *)syncContext
{
	return (YES);
}

#pragma mark - Properties
- (NSData *)_archivedServerItemData
{
	if ((_archivedServerItemData == nil) && (_archivedServerItem != nil))
	{
		_archivedServerItemData = [NSKeyedArchiver archivedDataWithRootObject:_archivedServerItem];
	}

	return (_archivedServerItemData);
}

- (OCItem *)archivedServerItem
{
	if ((_archivedServerItem == nil) && (_archivedServerItemData != nil))
	{
		_archivedServerItem = [NSKeyedUnarchiver unarchiveObjectWithData:_archivedServerItemData];
	}

	return (_archivedServerItem);
}

#pragma mark - NSSecureCoding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_identifier forKey:@"identifier"];

	[coder encodeObject:_localItem forKey:@"localItem"];

	[coder encodeObject:[self _archivedServerItemData] forKey:@"archivedServerItemData"];
	[coder encodeObject:_parameters forKey:@"parameters"];

	[self encodeActionData:coder];
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [self init]) != nil)
	{
		_identifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"identifier"];

		_localItem = [decoder decodeObjectOfClass:[OCItem class] forKey:@"localItem"];
		_archivedServerItemData = [decoder decodeObjectOfClass:[NSData class] forKey:@"archivedServerItemData"];

		_parameters = [decoder decodeObjectOfClass:[NSDictionary class] forKey:@"parameters"];

		[self decodeActionData:decoder];
	}

	return (self);
}

- (void)encodeActionData:(NSCoder *)coder
{
}

- (void)decodeActionData:(NSCoder *)decoder
{
}

@end
