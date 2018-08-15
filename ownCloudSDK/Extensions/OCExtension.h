//
//  OCExtension.h
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
#import "OCExtensionTypes.h"
#import "OCExtensionLocation.h"
#import "OCExtensionContext.h"

@interface OCExtension : NSObject

@property(strong) OCExtensionType type;	//!< The type of extension.

@property(strong) NSArray<OCExtensionLocation *> *locations; //!< (optional) array of locations this extension is limited to

@property(strong) OCExtensionIdentifier identifier; //!< Identifier uniquely identifying the extension.
@property(strong) OCExtensionPriority priority; //!< Priority of the extension in comparison to others. Smaller values rank higher. Value is used by default by -matchesContext:

@property(strong) OCExtensionRequirements satisfiedRequirements; //!< Requirements this extension satisfies

- (OCExtensionPriority)matchesContext:(OCExtensionContext *)context; //!< Returns the priority with which the extension meets the context's criteria. Returns nil if it does not meet the criteria.

- (id)provideObjectForContext:(OCExtensionContext *)context error:(NSError **)outError; //!< Provides the object (usually a new instance of whatever the extension implements) for the provided context. Returns any errors in outError.

@end
