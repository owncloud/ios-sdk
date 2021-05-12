//
//  OCAuthenticationBrowserSession.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 02.12.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCAuthenticationBrowserSession.h"

@implementation OCAuthenticationBrowserSession

- (instancetype)initWithURL:(NSURL *)authorizationRequestURL callbackURLScheme:(NSString *)scheme options:(nullable OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(OCAuthenticationBrowserSessionCompletionHandler)completionHandler
{
	if ((self = [super init]) != nil)
	{
		_url = authorizationRequestURL;
		_scheme = scheme;
		_options = options;
		_completionHandler = [completionHandler copy];
	}

	return (self);
}

- (UIViewController *)hostViewController
{
	return (_options[OCAuthenticationMethodPresentingViewControllerKey]);
}

- (BOOL)start
{
	return (NO);
}

- (void)completedWithCallbackURL:(nullable NSURL *)callbackURL error:(nullable NSError *)error
{
	if (_completionHandler != nil)
	{
		_completionHandler(callbackURL, error);
		_completionHandler = nil;
	}
}

#pragma mark - Class settings
+ (OCClassSettingsIdentifier)classSettingsIdentifier
{
	return (OCClassSettingsIdentifierBrowserSession);
}

+ (nullable NSDictionary<OCClassSettingsKey, id> *)defaultSettingsForIdentifier:(OCClassSettingsIdentifier)identifier
{
	return (@{});
}

@end

OCClassSettingsIdentifier OCClassSettingsIdentifierBrowserSession = @"browser-session";
