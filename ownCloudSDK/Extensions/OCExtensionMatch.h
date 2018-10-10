//
//  OCExtensionMatch.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 23.08.18.
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
#import "OCExtension.h"

@interface OCExtensionMatch : NSObject

@property(strong,readonly) OCExtension *extension; //!< A matching extension
@property(assign,readonly) OCExtensionPriority priority; //!< The priority with which the extension matched

- (instancetype)initWithExtension:(OCExtension *)extension priority:(OCExtensionPriority)priority;

@end
