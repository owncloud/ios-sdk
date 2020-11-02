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

NS_ASSUME_NONNULL_BEGIN

typedef id _Nullable (^OCExtensionObjectProvider)(OCExtension *extension, OCExtensionContext *context, NSError * __nullable * __nullable outError);
typedef OCExtensionPriority(^OCExtensionCustomContextMatcher)(OCExtensionContext *context, OCExtensionPriority defaultPriority);

@interface OCExtension : NSObject

@property(strong) OCExtensionType type;	//!< The type of extension.

@property(nullable,strong) NSArray<OCExtensionLocation *> *locations; //!< (optional) array of locations this extension is limited to

@property(strong) OCExtensionIdentifier identifier; //!< Identifier uniquely identifying the extension.
@property(assign) OCExtensionPriority priority; //!< Priority of the extension in comparison to others. Larger values rank higher. Value is used by default by -matchesContext:

@property(nullable,strong) OCExtensionRequirements features; //!< Requirements this extension satisfies

@property(nullable,strong) OCExtensionMetadata extensionMetadata; //!< Dictionary with descriptive metadata (for presentation)

@property(nullable,copy) OCExtensionObjectProvider objectProvider; //!< Block to provide the object to return for calls to -provideObjectForContext:error:.
@property(nullable,copy) OCExtensionCustomContextMatcher customMatcher; //!< Block to manipulate the extension priority returned by -matchesContext: without having to subclass OCExtension

+ (instancetype)extensionWithIdentifier:(OCExtensionIdentifier)identifier type:(OCExtensionType)type location:(nullable OCExtensionLocationIdentifier)locationIdentifier features:(nullable OCExtensionRequirements)features objectProvider:(nullable OCExtensionObjectProvider)objectProvider;
- (instancetype)initWithIdentifier:(OCExtensionIdentifier)identifier type:(OCExtensionType)type location:(nullable OCExtensionLocationIdentifier)locationIdentifier features:(nullable OCExtensionRequirements)features objectProvider:(nullable OCExtensionObjectProvider)objectProvider;
- (instancetype)initWithIdentifier:(OCExtensionIdentifier)identifier type:(OCExtensionType)type locations:(nullable NSArray <OCExtensionLocationIdentifier> *)locationIdentifiers features:(nullable OCExtensionRequirements)features objectProvider:(nullable OCExtensionObjectProvider)objectProvider customMatcher:(nullable OCExtensionCustomContextMatcher)customMatcher;

- (OCExtensionPriority)matchesContext:(OCExtensionContext *)context; //!< Returns the priority with which the extension meets the context's criteria. Returns nil if it does not meet the criteria.

- (nullable id)provideObjectForContext:(OCExtensionContext *)context; //!< Provides the object (usually a new instance of whatever the extension implements) for the provided context. Returns any errors in context.error.

@end

extern OCExtensionMetadataKey OCExtensionMetadataKeyName; //!< Name of the extension
extern OCExtensionMetadataKey OCExtensionMetadataKeyDescription; //!< Describes the purpose of the extension
extern OCExtensionMetadataKey OCExtensionMetadataKeyVersion; //!< Version of the extension
extern OCExtensionMetadataKey OCExtensionMetadataKeyCopyright; //!< Copyright information for the extension

NS_ASSUME_NONNULL_END
