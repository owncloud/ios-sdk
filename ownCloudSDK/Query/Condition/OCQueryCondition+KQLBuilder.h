//
//  OCQueryCondition+KQLBuilder.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 19.11.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCQueryCondition.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCKQLString;

typedef NS_OPTIONS(NSInteger, OCKQLSearchedContent) {
	OCKQLSearchedContentItemName = (1L << 0L),
	OCKQLSearchedContentContents  = (1L << 1L)
};

@interface OCQueryCondition (KQLBuilder)

- (OCKQLString)kqlStringWithTypeAliasToKQLTypeMap:(NSDictionary<NSString *, NSString *> *)typeAliasToKQLTypeMap targetContent:(OCKQLSearchedContent)targetContent;

@end

NS_ASSUME_NONNULL_END
