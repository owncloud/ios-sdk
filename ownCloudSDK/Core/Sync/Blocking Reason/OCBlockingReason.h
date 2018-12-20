//
//  OCBlockingReason.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.12.18.
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

typedef NSString* OCBlockingReasonOption;

@interface OCBlockingReason : NSObject

- (void)tryResolutionWithOptions:(nullable NSDictionary<OCBlockingReasonOption, id> *)options completionHandler:(void(^)(BOOL resolved, NSError * _Nullable resolutionError))completionHandler; //!< Try resolving the reason for blocking. Returns YES for resolved if the blocking reason no longer applies, NO if it continues to apply. If the reason is no longer valid due to an error, the error is returned as resolutionError.

@end

extern OCBlockingReasonOption OCBlockingReasonOptionCore; //!< Instance of OCCore.

NS_ASSUME_NONNULL_END
