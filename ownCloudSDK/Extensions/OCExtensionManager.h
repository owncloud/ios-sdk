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
#import "OCExtensionMatch.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCExtensionManager : NSObject
{
	NSMutableArray <OCExtension *> *_extensions;
	NSArray <OCExtension *> *_cachedExtensions;
}

@property(strong,readonly,class,nonatomic) OCExtensionManager *sharedExtensionManager;

@property(strong,readonly,nonatomic) NSArray <OCExtension *> *extensions;

- (void)addExtension:(OCExtension *)extension;
- (void)removeExtension:(OCExtension *)extension;

- (nullable NSArray <OCExtensionMatch *> *)provideExtensionsForContext:(OCExtensionContext *)context error:(NSError * _Nullable *)outError; //!< Matches extensions against a given context. Extensions with higher priority rank first.
- (void)provideExtensionsForContext:(OCExtensionContext *)context completionHandler:(void(^)(NSError * _Nullable error, OCExtensionContext *context, NSArray <OCExtensionMatch *> * _Nullable))completionHandler; //!< Async matching of extensions against a given context. Expect the completionHandler to be called on a different thread. Prefer this API over -provideExtensionsForContext:error: whenever feasible.

@end

NS_ASSUME_NONNULL_END
