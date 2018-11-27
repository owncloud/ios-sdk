//
//  OCExtension+License.h
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

#import "OCExtension.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCExtension (License)

+ (instancetype)licenseExtensionWithIdentifier:(NSString *)identifier bundleOfClass:(Class)class title:(NSString *)title resourceName:(NSString *)resourceName fileExtension:(nullable NSString *)fileExtension;
+ (instancetype)licenseExtensionWithIdentifier:(NSString *)identifier bundle:(NSBundle *)bundle title:(NSString *)title resourceName:(NSString *)resourceName fileExtension:(nullable NSString *)fileExtension;

@end

/**
	Extension type to expose a license's text.

	Provided object: dictionary with the following keys:
		- "title" [NSString]: title to use before the license text
		- "url" [NSURL]: URL of the license text. The suffix should indicate file type. Unknown suffixes are handled as plain text.
*/
extern OCExtensionType OCExtensionTypeLicense;

NS_ASSUME_NONNULL_END

#import "OCExtensionManager.h"
