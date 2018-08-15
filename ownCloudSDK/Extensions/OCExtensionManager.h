//
//  OCExtensionManager.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.08.18.
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

#import <Foundation/Foundation.h>
#import "OCExtensionTypes.h"
#import "OCExtension.h"
#import "OCExtensionContext.h"

@interface OCExtensionManager : NSObject

@property(strong,readonly) NSArray <OCExtension *> *extensions;

- (void)addExtension:(OCExtension *)extension;
- (void)removeExtension:(OCExtension *)extension;

- (void)provideExtensionsForRequest:(OCExtensionContext *)request maximumCount:(NSUInteger)maximumCount completionHandler:(void(^)(NSError *error, NSArray <OCExtension *> *))completionHandler;

@end
