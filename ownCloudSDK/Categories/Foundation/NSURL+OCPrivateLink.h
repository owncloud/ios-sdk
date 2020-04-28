//
//  NSURL+OCPrivateLink.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 22.04.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCTypes.h"

@class OCCore;

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCPrivateLinkFileID;

@interface NSURL (OCPrivateLink)

@property(readonly,nonatomic,nullable) OCPrivateLinkFileID privateLinkFileID;

- (nullable OCFileIDUniquePrefix)fileIDUniquePrefixFromPrivateLinkInCore:(OCCore *)core; //!< Returns the fileID (if any) for the private link (if any) for the provided core.

@end

NS_ASSUME_NONNULL_END
