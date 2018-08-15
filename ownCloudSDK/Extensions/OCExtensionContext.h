//
//  OCExtensionContext.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.08.18.
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
#import "OCExtensionLocation.h"

@interface OCExtensionContext : NSObject

@property(strong) OCExtensionLocation *location; //!< The type and location of the extension(s) that suit this context.

@property(strong) OCExtensionRequirements requirements; //!< Optional requirements that extension(s) must meet to suit the context.

@end
