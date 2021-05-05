//
//  OCAuthenticationBrowserSessionCustomScheme.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.05.21.
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

#import "OCAuthenticationBrowserSessionCustomScheme.h"
#import "NSError+OCError.h"
#import "OCLogger.h"
#import "OCMacros.h"

@protocol ApplicationOpenURL <NSObject>

- (BOOL)canOpenURL:(NSURL *)url;
- (BOOL)openURL:(NSURL*)url;
- (void)openURL:(NSURL*)url options:(NSDictionary<UIApplicationOpenExternalURLOptionsKey, id> *)options completionHandler:(void (^ __nullable)(BOOL success))completion;

@end

static OCAuthenticationBrowserSessionCustomScheme *sActiveSession;
static OCAuthenticationBrowserSessionCustomSchemeBusyPresenter sBusyPresenter;

@interface OCAuthenticationBrowserSessionCustomScheme ()
{
	dispatch_block_t _cancelBusyPresenter;
	BOOL _isCompleted;
}
@end

@implementation OCAuthenticationBrowserSessionCustomScheme

+ (void)load
{
	[self registerOCClassSettingsDefaults:@{
	} metadata:@{
		OCClassSettingsKeyItemBrowserSessionCustomSchemePlain : @{
			OCClassSettingsMetadataKeyType 	      	 : OCClassSettingsMetadataTypeString,
			OCClassSettingsMetadataKeyDescription 	 : @"Scheme to use instead of plain `http` when using browser session class CustomScheme, i.e. `mibrowser`.",
			OCClassSettingsMetadataKeyCategory    	 : @"Browser Session",
			OCClassSettingsMetadataKeyStatus	 : OCClassSettingsKeyStatusAdvanced
		},

		OCClassSettingsKeyItemBrowserSessionCustomSchemeSecure : @{
			OCClassSettingsMetadataKeyType 	      	 : OCClassSettingsMetadataTypeString,
			OCClassSettingsMetadataKeyDescription 	 : @"Scheme to use instead of `https` when using browser session class CustomScheme, i.e. `mibrowsers`.",
			OCClassSettingsMetadataKeyCategory    	 : @"Browser Session",
			OCClassSettingsMetadataKeyStatus	 : OCClassSettingsKeyStatusAdvanced
		}
	}];
}

+ (void)setActiveSession:(OCAuthenticationBrowserSessionCustomScheme *)activeSession
{
	sActiveSession = activeSession;
}

+ (OCAuthenticationBrowserSessionCustomScheme *)activeSession
{
	return (sActiveSession);
}

+ (void)setBusyPresenter:(OCAuthenticationBrowserSessionCustomSchemeBusyPresenter)busyPresenter
{
	sBusyPresenter = [busyPresenter copy];
}

+ (OCAuthenticationBrowserSessionCustomSchemeBusyPresenter)busyPresenter
{
	return (sBusyPresenter);
}

+ (BOOL)handleOpenURL:(NSURL *)url
{
	OCAuthenticationBrowserSessionCustomScheme *activeSession;

	if ((activeSession = self.activeSession) != nil)
	{
		if ([url.scheme isEqual:activeSession.scheme])
		{
			[activeSession completedWithCallbackURL:url error:nil];

			return (YES);
		}
	}

	return (NO);
}

- (NSString *)plainCustomScheme
{
	return ([self classSettingForOCClassSettingsKey:OCClassSettingsKeyItemBrowserSessionCustomSchemePlain]);
}

- (NSString *)secureCustomScheme
{
	return ([self classSettingForOCClassSettingsKey:OCClassSettingsKeyItemBrowserSessionCustomSchemeSecure]);
}

- (nullable NSURL *)customSchemeURLForWebURL:(NSURL *)webURL
{
	if ([webURL.scheme.lowercaseString isEqual:@"http"] && (self.plainCustomScheme != nil))
	{
		return ([NSURL URLWithString:[self.plainCustomScheme stringByAppendingString:[webURL.absoluteString substringFromIndex:4]]]);
	}
	else if ([webURL.scheme.lowercaseString isEqual:@"https"] && (self.secureCustomScheme != nil))
	{
		return ([NSURL URLWithString:[self.secureCustomScheme stringByAppendingString:[webURL.absoluteString substringFromIndex:5]]]);
	}

	return (nil);
}

- (BOOL)start
{
	Class uiApplicationClass = NSClassFromString(@"UIApplication");
	id<ApplicationOpenURL> sharedApplication = [uiApplicationClass valueForKey:@"sharedApplication"];
	NSURL *customSchemeURL;

	if ((customSchemeURL = [self customSchemeURLForWebURL:self.url]) != nil)
	{
		if (sharedApplication != nil)
		{
			OCAuthenticationBrowserSessionCustomSchemeBusyPresenter busyPresenter = OCAuthenticationBrowserSessionCustomScheme.busyPresenter;

			if (busyPresenter != nil)
			{
				__weak OCAuthenticationBrowserSessionCustomScheme *weakSelf = self;
				_cancelBusyPresenter = [busyPresenter(self, ^{
					[weakSelf completedWithCallbackURL:nil error:OCError(OCErrorAuthorizationCancelled)];
				}) copy];
			}

			[sharedApplication openURL:customSchemeURL options:@{} completionHandler:^(BOOL success) {
				if (!success)
				{
					[self completedWithCallbackURL:nil error:OCErrorWithDescription(OCErrorAuthorizationCantOpenCustomSchemeURL, ([NSString stringWithFormat:OCLocalized(@"Can't open custom scheme URL %@."), customSchemeURL]))];
				}
				else
				{
					OCAuthenticationBrowserSessionCustomScheme.activeSession = self;
				}
			}];

			return (YES);
		}
		else
		{
			OCLogError(@"Can't open URL %@", customSchemeURL);
		}

		[self completedWithCallbackURL:nil error:OCErrorWithDescription(OCErrorAuthorizationCantOpenCustomSchemeURL, ([NSString stringWithFormat:OCLocalized(@"Can't open custom scheme URL %@."), customSchemeURL]))];
	}
	else
	{
		[self completedWithCallbackURL:nil error:OCErrorWithDescription(OCErrorAuthorizationCantOpenCustomSchemeURL, ([NSString stringWithFormat:OCLocalized(@"Can't build custom scheme URL from %@."), self.url]))];
	}

	return (NO);
}

- (void)completedWithCallbackURL:(NSURL *)callbackURL error:(NSError *)error
{
	if (!_isCompleted)
	{
		_isCompleted = YES;

		[super completedWithCallbackURL:callbackURL error:error];
		self.class.activeSession = nil;

		if (_cancelBusyPresenter != nil)
		{
			_cancelBusyPresenter();
			_cancelBusyPresenter = nil;
		}
	}
}

@end

OCClassSettingsKey OCClassSettingsKeyItemBrowserSessionCustomSchemePlain = @"custom-scheme-plain";
OCClassSettingsKey OCClassSettingsKeyItemBrowserSessionCustomSchemeSecure = @"custom-scheme-secure";
