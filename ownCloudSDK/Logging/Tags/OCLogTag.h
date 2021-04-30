//
//  OCLogTag.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 12.12.18.
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

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCLogTagName;

@protocol OCLogTagging <NSObject>
+ (NSArray<OCLogTagName> *)logTags;
- (NSArray<OCLogTagName> *)logTags;
@end

#define OCLogTagTypedID(idType,identfr) ((identfr!=nil)?[NSString stringWithFormat:@"%@:%@",idType,identfr]:nil)
#define OCLogTagInstance(obj) [NSString stringWithFormat:@"Instance:%p",obj]

NS_ASSUME_NONNULL_END
