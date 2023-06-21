//
//  OCBookmark+ServerInstance.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.03.23.
//  Copyright © 2023 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2023, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCBookmark.h"

@class OCBookmark;
@class OCServerInstance;

NS_ASSUME_NONNULL_BEGIN

@interface OCBookmark (ServerInstance)

- (void)applyServerInstance:(OCServerInstance *)serverInstance; //!< Applies the server instance on the bookmark, so that the bookmark can be used to connect to the server instance

@end

NS_ASSUME_NONNULL_END
