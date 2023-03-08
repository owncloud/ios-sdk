//
//  OCAppProvider.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.09.22.
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

#import "OCAppProvider.h"
#import "OCMacros.h"
#import "OCAppProviderApp.h"
#import "OCAppProviderFileType.h"
#import "NSArray+OCFiltering.h"

@implementation OCAppProvider

- (BOOL)isSupported
{
	return (
		// Require version 1.1.X
		[self.version hasPrefix:@"1.1."] &&

		// Require open_web_url
		(self.openWebURLPath != nil) &&

		// Require new_url
		(self.createURLPath != nil)
	);
}

- (void)setAppList:(OCAppProviderAppList)inAppList
{
	OCAppProviderAppList newAppList;

	// Response format documented at https://owncloud.dev/services/app-registry/apps/
	if ((newAppList = OCTypedCast(inAppList,NSArray)) != nil)
	{
		NSMutableArray<OCAppProviderApp *> *apps = [NSMutableArray new];
		NSMutableArray<OCAppProviderFileType *> *types = [NSMutableArray new];

		for (NSDictionary<OCAppProviderKey,id> *inAppDict in newAppList)
		{
			NSDictionary<OCAppProviderKey,id> *appDict;

			if ((appDict = OCTypedCast(inAppDict, NSDictionary)) != nil)
			{
				OCMIMEType typeMIMEType = OCTypedCast(appDict[OCAppProviderKeyMIMEType], NSString);
				OCFileExtension typeExtension = OCTypedCast(appDict[OCAppProviderKeyExtension], NSString);
				NSString *typeName = OCTypedCast(appDict[OCAppProviderKeyName], NSString);
				NSString *typeIconURLString = OCTypedCast(appDict[OCAppProviderKeyIcon], NSString);
				NSString *typeDescription = OCTypedCast(appDict[OCAppProviderKeyDescription], NSString);
				NSNumber *typeAllowCreation = OCTypedCast(appDict[OCAppProviderKeyAllowCreation], NSNumber);
				OCAppProviderAppName typeDefaultAppName = OCTypedCast(appDict[OCAppProviderKeyDefaultApplication], NSString);
				NSArray<NSDictionary<OCAppProviderKey,NSString *> *> *typeAppProviders = OCTypedCast(appDict[OCAppProviderKeyAppProviders], NSArray);

				if ((typeMIMEType != nil) && (typeAppProviders.count > 0))
				{
					OCAppProviderFileType *type = [OCAppProviderFileType new];

					type.provider = self;

					type.mimeType = typeMIMEType;
					type.extension = typeExtension;
					type.name = typeName;
					if (typeIconURLString != nil)
					{
						type.iconURL = [[NSURL alloc] initWithString:typeIconURLString];
					}
					type.typeDescription = typeDescription;
					type.allowCreation = typeAllowCreation.boolValue;
					type.defaultAppName = typeDefaultAppName;

					for (NSDictionary<OCAppProviderKey,NSString *> *inAppProviderDict in typeAppProviders)
					{
						NSDictionary<OCAppProviderKey,NSString *> *appProviderDict;

						if ((appProviderDict = OCTypedCast(inAppProviderDict, NSDictionary)) != nil)
						{
							OCAppProviderAppName appName = OCTypedCast(appProviderDict[OCAppProviderKeyAppProviderName], NSString);
							NSString *appIconURLString = OCTypedCast(appProviderDict[OCAppProviderKeyAppProviderIcon], NSString);
							NSURL *appIconURL = (appIconURLString != nil) ? [[NSURL alloc] initWithString:appIconURLString] : nil;
							OCAppProviderApp *app = nil;

							if (appName != nil)
							{
								// Look for app with same name and iconURL
								app = [apps firstObjectMatching:^BOOL(OCAppProviderApp * _Nonnull existingApp) {
									return ([existingApp.name isEqual:appName] && [existingApp.iconURL isEqual:appIconURL]);
								}];
							}

							if (app == nil)
							{
								// Create new app
								app = [OCAppProviderApp new];

								app.provider = self;

								app.name = appName;
								app.iconURL = appIconURL;

								[apps addObject:app];
							}

							if ((typeDefaultAppName != nil) && [app.name isEqual:typeDefaultAppName])
							{
								type.defaultApp = app;
							}

							[app addSupportedType:type];
						}
					}

					[types addObject:type];
				}
			}
		}

		_apps = apps;
		_types = types;
		_appList = newAppList;
	}
}

#pragma mark - Description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p, enabled: %d%@, supported: %d%@%@%@%@%@%@>", NSStringFromClass(self.class), self,
		self.enabled,
		OCExpandVar(version),
		self.isSupported,
		OCExpandVar(appsURLPath),
		OCExpandVar(openURLPath),
		OCExpandVar(openWebURLPath),
		OCExpandVar(createURLPath),
		OCExpandVar(apps),
		OCExpandVar(types)
	]);
}

@end

OCAppProviderKey OCAppProviderKeyMIMEType = @"mime_type";
OCAppProviderKey OCAppProviderKeyExtension = @"ext";
OCAppProviderKey OCAppProviderKeyName = @"name";
OCAppProviderKey OCAppProviderKeyIcon = @"icon";
OCAppProviderKey OCAppProviderKeyDescription = @"description";
OCAppProviderKey OCAppProviderKeyAllowCreation = @"allow_creation";
OCAppProviderKey OCAppProviderKeyDefaultApplication = @"default_application";
OCAppProviderKey OCAppProviderKeyAppProviders = @"app_providers";

OCAppProviderKey OCAppProviderKeyAppProviderName = @"name";
OCAppProviderKey OCAppProviderKeyAppProviderIcon = @"icon";
