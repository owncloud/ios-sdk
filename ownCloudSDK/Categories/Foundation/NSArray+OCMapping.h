//
//  NSArray+OCMapping.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 17.05.22.
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

NS_ASSUME_NONNULL_BEGIN

typedef id _Nullable (^OCObjectToKeyMapper)(id obj);
typedef id _Nullable (^OCObjectToObjectMapper)(id obj);

@interface NSArray (OCMapping)

- (NSMutableDictionary *)dictionaryUsingMapper:(OCObjectToKeyMapper)mapper;
- (NSMutableSet *)setUsingMapper:(OCObjectToObjectMapper)mapper;
- (NSMutableArray *)arrayUsingMapper:(OCObjectToObjectMapper)mapper;

@end

NS_ASSUME_NONNULL_END
