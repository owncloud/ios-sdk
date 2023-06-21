//
//  NSArray+OCFiltering.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.04.22.
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

@interface NSArray<ObjectType> (OCFiltering)

- (NSArray<ObjectType> *)filteredArrayUsingBlock:(BOOL(^)(ObjectType object, BOOL * _Nonnull stop))filter; //!< Returns a new array with all objects passing the provided filter block. Iteration can be stopped at any time by setting *stop to true.

- (nullable ObjectType)firstObjectMatching:(BOOL(^)(ObjectType object))matcher; //!< Returns the first object matching the provided matcher block

@end

NS_ASSUME_NONNULL_END
