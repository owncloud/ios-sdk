//
//  OCCellularSwitch.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.05.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCCellularSwitch.h"
#import "OCAppIdentity.h"
#import "OCCellularManager.h"
#import "OCConnection.h"

@implementation OCCellularSwitch

@synthesize maximumTransferSize = _maximumTransferSize;

- (instancetype)initWithIdentifier:(OCCellularSwitchIdentifier)identifier localizedName:(nullable NSString *)localizedName prefsKey:(nullable NSString *)prefsKey defaultValue:(BOOL)defaultAllowed maximumTransferSize:(NSUInteger)maximumTransferSize
{
	if ((self = [super init]) != nil)
	{
		_identifier = identifier;
		_localizedName = localizedName;
		_prefsKey = prefsKey;
		_allowed = defaultAllowed;
		_maximumTransferSize = maximumTransferSize;
	}

	return (self);
}

- (instancetype)initWithIdentifier:(OCCellularSwitchIdentifier)identifier localizedName:(nullable NSString *)localizedName defaultValue:(BOOL)defaultAllowed maximumTransferSize:(NSUInteger)maximumTransferSize
{
	return ([self initWithIdentifier:identifier localizedName:localizedName prefsKey:[@"cellular-access:" stringByAppendingString:identifier] defaultValue:defaultAllowed maximumTransferSize:maximumTransferSize]);
}

- (BOOL)allowed
{
	if (_prefsKey != nil)
	{
		NSNumber *allowedNumber;

		if ((allowedNumber = [OCAppIdentity.sharedAppIdentity.userDefaults objectForKey:_prefsKey]) != nil)
		{
			return (allowedNumber.boolValue);
		}
	}

	return (_allowed);
}

- (void)setAllowed:(BOOL)allowed
{
	_allowed = allowed;

	if (_prefsKey != nil)
	{
		[OCAppIdentity.sharedAppIdentity.userDefaults setObject:@(allowed) forKey:_prefsKey];
	}

	[NSNotificationCenter.defaultCenter postNotificationName:OCCellularSwitchUpdatedNotification object:self];
}

- (NSUInteger)maximumTransferSize
{
	if (_prefsKey != nil)
	{
		NSNumber *allowedNumber;

		if ((allowedNumber = [OCAppIdentity.sharedAppIdentity.userDefaults objectForKey:[_prefsKey stringByAppendingString:@":max-size"]]) != nil)
		{
			return (allowedNumber.unsignedIntegerValue);
		}
	}

	return (_maximumTransferSize);
}

- (void)setMaximumTransferSize:(NSUInteger)maximumTransferSize
{
	_maximumTransferSize = maximumTransferSize;

	if (_prefsKey != nil)
	{
		[OCAppIdentity.sharedAppIdentity.userDefaults setObject:@(maximumTransferSize) forKey:[_prefsKey stringByAppendingString:@":max-size"]];
	}

	[NSNotificationCenter.defaultCenter postNotificationName:OCCellularSwitchUpdatedNotification object:self];
}

- (BOOL)allowsTransferOfSize:(NSUInteger)transferSize
{
	if (self.allowed && OCConnection.allowCellular)
	{
		NSUInteger maxTransferSize = self.maximumTransferSize;

		return ((maxTransferSize == 0) || ((maxTransferSize!=0) && (transferSize < maxTransferSize)));
	}

	return (NO);
}

@end

OCCellularSwitchIdentifier OCCellularSwitchIdentifierMain = @"main";
OCCellularSwitchIdentifier OCCellularSwitchIdentifierAvailableOffline = @"available-offline";

NSNotificationName OCCellularSwitchUpdatedNotification = @"OCCellularSwitchUpdated";
