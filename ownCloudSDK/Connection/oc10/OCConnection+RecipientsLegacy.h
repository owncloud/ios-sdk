//
//  OCConnection+Recipients10.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 09.12.24.
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

#import <Foundation/Foundation.h>
#import "OCFeatureAvailability.h"

// OC 10
#if OC_LEGACY_SUPPORT

NS_ASSUME_NONNULL_BEGIN

@interface OCConnection (RecipientsLegacy)

- (nullable NSProgress *)legacyRetrieveRecipientsForItemType:(OCItemType)itemType ofShareType:(nullable NSArray <OCShareTypeID> *)shareTypes searchTerm:(nullable NSString *)searchTerm maximumNumberOfRecipients:(NSUInteger)maximumNumberOfRecipients completionHandler:(OCConnectionRecipientsRetrievalCompletionHandler)completionHandler;

@end

NS_ASSUME_NONNULL_END

#endif /* OC_LEGACY_SUPPORT */
