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

@class OCExtension;

typedef id(^OCExtensionObjectProvider)(OCExtension *extension, OCExtensionContext *context, NSError **outError);
typedef OCExtensionPriority(^OCExtensionCustomContextMatcher)(OCExtensionContext *context, OCExtensionPriority defaultPriority);

@interface OCExtension : NSObject

@property(strong) OCExtensionType type;	//!< The type of extension.

@property(strong) NSArray<OCExtensionLocation *> *locations; //!< (optional) array of locations this extension is limited to

@property(strong) OCExtensionIdentifier identifier; //!< Identifier uniquely identifying the extension.
@property(assign) OCExtensionPriority priority; //!< Priority of the extension in comparison to others. Larger values rank higher. Value is used by default by -matchesContext:

@property(strong) OCExtensionRequirements features; //!< Requirements this extension satisfies

@property(copy) OCExtensionObjectProvider objectProvider; //!< Block to provide the object to return for calls to -provideObjectForContext:error:.
@property(copy) OCExtensionCustomContextMatcher customMatcher; //!< Block to manipulate the extension priority returned by -matchesContext: without having to subclass OCExtension

+ (instancetype)extensionWithIdentifier:(OCExtensionIdentifier)identifier type:(OCExtensionType)type location:(OCExtensionLocationIdentifier)locationIdentifier features:(OCExtensionRequirements)features objectProvider:(OCExtensionObjectProvider)objectProvider;
- (instancetype)initWithIdentifier:(OCExtensionIdentifier)identifier type:(OCExtensionType)type location:(OCExtensionLocationIdentifier)locationIdentifier features:(OCExtensionRequirements)features objectProvider:(OCExtensionObjectProvider)objectProvider;
- (instancetype)initWithIdentifier:(OCExtensionIdentifier)identifier type:(OCExtensionType)type locations:(NSArray <OCExtensionLocationIdentifier> *)locationIdentifiers features:(OCExtensionRequirements)features objectProvider:(OCExtensionObjectProvider)objectProvider customMatcher:(OCExtensionCustomContextMatcher)customMatcher;

- (OCExtensionPriority)matchesContext:(OCExtensionContext *)context; //!< Returns the priority with which the extension meets the context's criteria. Returns nil if it does not meet the criteria.

- (id)provideObjectForContext:(OCExtensionContext *)context; //!< Provides the object (usually a new instance of whatever the extension implements) for the provided context. Returns any errors in outError.

@end
