//
//  OCLogComponent.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 11.12.18.
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

#import "OCLogComponent.h"
#import "OCIPNotificationCenter.h"
#import "OCAppIdentity.h"
#import "OCLogger.h"
#import "OCMacros.h"

@implementation OCLogComponent

@synthesize enabled = _enabled;
@synthesize identifier = _identifier;

- (instancetype)initWithIdentifier:(OCLogComponentIdentifier)identifier
{
	if ((self = [super init]) != nil)
	{
		_identifier = identifier;

		[self determineEnabledForceNotify:YES];

		[OCIPNotificationCenter.sharedNotificationCenter addObserver:self forName:[self _enabledNotificationName] withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, OCLogComponent * _Nonnull logComponent, OCIPCNotificationName  _Nonnull notificationName) {
			[logComponent determineEnabledForceNotify:NO];
		}];
	}

	return (self);
}

- (void)dealloc
{
	[OCIPNotificationCenter.sharedNotificationCenter removeObserver:self forName:[self _enabledNotificationName]];
}

- (NSString *)name
{
	return (OCLocalized(@"Standard error output"));
}

- (OCIPCNotificationName)_enabledNotificationName
{
	return ([@"org.owncloud.log-component-enabled:" stringByAppendingString:self.identifier]);
}

- (NSString *)_enabledUserDefaultsKey
{
	return ([@"log-component-enabled:" stringByAppendingString:self.identifier]);
}

- (void)determineEnabledForceNotify:(BOOL)forceNotify
{
	NSNumber *enabledNumber;
	BOOL wasEnabled = _enabled;

	if ((enabledNumber = [OCAppIdentity.sharedAppIdentity.userDefaults objectForKey:[self _enabledUserDefaultsKey]]) != nil)
	{
		_enabled = enabledNumber.boolValue;
	}
	else
	{
		_enabled = [[OCLogger classSettingForOCClassSettingsKey:OCClassSettingsKeyLogEnabledComponents] containsObject:self.identifier];
	}

	if ((_enabled != wasEnabled) || forceNotify)
	{
		[self enabledChangedTo:_enabled];
	}
}

- (void)setEnabled:(BOOL)enabled
{
	BOOL wasEnabled = _enabled;

	_enabled = enabled;

	[OCAppIdentity.sharedAppIdentity.userDefaults setBool:enabled forKey:[self _enabledUserDefaultsKey]];

	[OCIPNotificationCenter.sharedNotificationCenter postNotificationForName:[self _enabledNotificationName] ignoreSelf:YES];

	if (_enabled != wasEnabled)
	{
		[self enabledChangedTo:_enabled];
	}
}

- (void)enabledChangedTo:(BOOL)enabled
{

}

@end
