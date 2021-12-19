//
//  OCLocale.h
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

#import <Foundation/Foundation.h>
#import "OCLocaleFilter.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCLocale : NSObject

@property(readonly,class,nonatomic) OCLocale *sharedLocale;
@property(readonly,nonatomic,strong) NSArray<OCLocaleFilter *> *filters;

- (void)addFilter:(OCLocaleFilter *)filter;
- (void)removeFilter:(OCLocaleFilter *)filter;

- (NSString *)localizeString:(NSString *)string bundle:(nullable NSBundle *)bundle table:(nullable NSString *)table options:(nullable OCLocaleOptions)options;

+ (NSString *)localizeString:(NSString *)string;
+ (NSString *)localizeString:(NSString *)string options:(nullable OCLocaleOptions)options;
+ (NSString *)localizeString:(NSString *)string table:(NSString *)table;
+ (NSString *)localizeString:(NSString *)string bundleOfClass:(Class)class;
+ (NSString *)localizeString:(NSString *)string bundleOfClass:(Class)class options:(nullable OCLocaleOptions)options;
+ (NSString *)localizeString:(NSString *)string bundleOfClass:(Class)class table:(NSString *)table;
+ (NSString *)localizeString:(NSString *)string bundleOfClass:(Class)class table:(NSString *)table options:(nullable OCLocaleOptions)options;

@end

NS_ASSUME_NONNULL_END
