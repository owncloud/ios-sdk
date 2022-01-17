//
//  OCPlatform.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 17.01.22.
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

#import <Foundation/Foundation.h>

#pragma mark - iOS, iPadOS, watchOS, tvOS

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>

#define OCView UIView
#endif /* TARGET_OS_IPHONE */

#pragma mark - macOS

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

#define OCView NSView
#endif /* TARGET_OS_OSX */

NS_ASSUME_NONNULL_BEGIN

@interface OCPlatform : NSObject

@end

NS_ASSUME_NONNULL_END
