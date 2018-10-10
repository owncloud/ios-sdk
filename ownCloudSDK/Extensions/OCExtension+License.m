//
//  OCExtension+License.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 23.08.18.
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

#import "OCExtension+License.h"

@implementation OCExtension (License)

+ (instancetype)licenseExtensionWithIdentifier:(NSString *)identifier bundleOfClass:(Class)class title:(NSString *)title resourceName:(NSString *)resourceName fileExtension:(NSString *)fileExtension
{
	return ([OCExtension licenseExtensionWithIdentifier:identifier bundle:[NSBundle bundleForClass:class] title:title resourceName:resourceName fileExtension:fileExtension]);
}

+ (instancetype)licenseExtensionWithIdentifier:(NSString *)identifier bundle:(NSBundle *)bundle title:(NSString *)title resourceName:(NSString *)resourceName fileExtension:(NSString *)fileExtension
{
	return ([OCExtension extensionWithIdentifier:identifier type:OCExtensionTypeLicense location:nil features:nil objectProvider:^id(OCExtension *extension, OCExtensionContext *context, NSError *__autoreleasing *outError) {
		NSURL *licenseURL;

		if ((licenseURL = [bundle URLForResource:resourceName withExtension:fileExtension]) != nil)
		{
			return (@{
				@"title" : title,
				@"url" : licenseURL
			});
		}

		if (outError != NULL)
		{
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
		}

		return (nil);
	}]);
}


@end

OCExtensionType OCExtensionTypeLicense = @"license";
