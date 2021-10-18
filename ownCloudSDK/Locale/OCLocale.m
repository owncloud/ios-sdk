//
//  OCLocale.m
//  OCLocale
//
//  Created by Felix Schwarz on 16.10.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCLocale.h"
#import "OCLocaleFilter.h"
#import "OCLocaleFilterClassSettings.h"
#import "OCLocaleFilterVariables.h"

@interface OCLocale ()
{
	NSArray<NSString *> *_preferredLanguages;
	NSMutableArray<OCLocaleFilter *> *_filters;
}
@end

@implementation OCLocale

+ (OCLocale *)sharedLocale
{
	static dispatch_once_t onceToken;
	static OCLocale *sharedLocale;

	dispatch_once(&onceToken, ^{
		sharedLocale = [OCLocale new];
		[sharedLocale addFilter:OCLocaleFilterClassSettings.shared];
		[sharedLocale addFilter:OCLocaleFilterVariables.shared];
	});

	return (sharedLocale);
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_preferredLanguages = NSLocale.preferredLanguages;
		_filters = [NSMutableArray new];
	}

	return (self);
}

- (void)addFilter:(OCLocaleFilter *)filter
{
	[_filters addObject:filter];
}

- (void)removeFilter:(OCLocaleFilter *)filter
{
	[_filters removeObject:filter];
}

+ (NSString *)localizeString:(NSString *)string
{
	return ([OCLocale.sharedLocale localizeString:string bundle:nil table:nil options:nil]);
}

+ (NSString *)localizeString:(NSString *)string options:(nullable OCLocaleOptions)options
{
	return ([OCLocale.sharedLocale localizeString:string bundle:nil table:nil options:options]);
}

+ (NSString *)localizeString:(NSString *)string table:(NSString *)table
{
	return ([OCLocale.sharedLocale localizeString:string bundle:nil table:table options:nil]);
}

+ (NSString *)localizeString:(NSString *)string bundleOfClass:(Class)class
{
	return ([OCLocale.sharedLocale localizeString:string bundle:[NSBundle bundleForClass:class] table:nil options:nil]);
}

+ (NSString *)localizeString:(NSString *)string bundleOfClass:(Class)class options:(nullable OCLocaleOptions)options;
{
	return ([OCLocale.sharedLocale localizeString:string bundle:[NSBundle bundleForClass:class] table:nil options:options]);
}

+ (NSString *)localizeString:(NSString *)string bundleOfClass:(Class)class table:(NSString *)table
{
	return ([OCLocale.sharedLocale localizeString:string bundle:[NSBundle bundleForClass:class] table:table options:nil]);
}

+ (NSString *)localizeString:(NSString *)string bundleOfClass:(Class)class table:(NSString *)table options:(nullable OCLocaleOptions)options
{
	return ([OCLocale.sharedLocale localizeString:string bundle:[NSBundle bundleForClass:class] table:table options:options]);
}

- (NSString *)localizeString:(NSString *)string bundle:(NSBundle *)bundle table:(NSString *)table options:(OCLocaleOptions)options
{
	NSBundle *localeBundle = bundle;
	NSString *localizedString = nil;

	if (localeBundle == nil)
	{
		localeBundle = NSBundle.mainBundle;
	}

	localizedString = [localeBundle localizedStringForKey:string value:string table:table];

	for (OCLocaleFilter *filter in _filters)
	{
		localizedString = [filter applyToLocalizedString:localizedString withOriginalString:string options:options];
	}

	return (localizedString);
}

@end
