//
//  OCProgress.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.02.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCProgressPathElementIdentifier;
typedef NSArray<OCProgressPathElementIdentifier>* OCProgressPath;
typedef NSMutableDictionary* OCProgressResolutionContext;
typedef NSString* OCProgressID;

@class OCProgress;

@protocol OCProgressResolver <NSObject>

@optional

@property(readonly,strong,nonatomic,nullable) OCProgressResolutionContext progressResolutionContext; //!< If nil is passed for context to -[OCProgress resolveWith:context:], the method uses this context if the Resolver provides it.

- (nullable NSProgress *)resolveProgress:(OCProgress *)progress withContext:(nullable OCProgressResolutionContext)context; //!< Resolve the progress starting from the -nextPathElement. Returns the NSProgress if resolution succeeds.
- (nullable id<OCProgressResolver>)resolverForPathElement:(OCProgressPathElementIdentifier)pathElementIdentifier withContext:(nullable OCProgressResolutionContext)context; //!< Returns the resolver responsible for a path element. If a different OCProgressResolver is returned, -resolveProgress: is not needed.

@end

@protocol OCProgressSource <OCProgressResolver>

@property(nonatomic,strong) OCProgressPath progressBasePath; //!< Base path to build the OCProgressPath of new OCProgress objects from.

@end

@interface OCProgress : NSObject <NSSecureCoding>

@property(readonly,strong) OCProgressID identifier; //!< Globally unique identifier of the progress object (typically an auto-generated UUID).

@property(strong) OCProgressPath path; //!< The progress path of the object that can be used for resolution.
@property(nullable,strong) NSProgress *progress; //!< The resolved progress object
@property(assign,nonatomic) BOOL cancelled; //!< Cancelled
@property(assign) BOOL cancellable; //!< Whether cancellation is possible

@property(copy) void(^cancellationHandler)(void); //!< Block of code to be executed when -cancel is called. (ephermal)

@property(strong) NSDictionary<NSString*, id<NSSecureCoding>> *userInfo; //!< Custom information that helps an OCProgressResolver provide the NSProgress object

- (instancetype)initWithPath:(OCProgressPath)path progress:(nullable NSProgress *)progress; //!< Createa a new OCProgress object from with the provided path. Optionally, an already known NSProgress object can be provided directly to save CPU cycles on resolution.

- (instancetype)initWithSource:(id<OCProgressSource>)source pathElementIdentifier:(OCProgressPathElementIdentifier)identifier progress:(nullable NSProgress *)progress; //!< Creates a new OCProgress object from the source's progressBasePath with the specified pathElementIdentifier. Optionally, an already known NSProgress object can be provided directly to save CPU cycles on resolution.

- (BOOL)nextPathElementIsLast; //!< Returns YES if the next path element is the last in the path.
- (nullable OCProgressPathElementIdentifier)nextPathElement; //!< Returns the next path element and moves the resolutionOffset to the next element.
- (void)resetResolutionOffset; //!< Resets the resolution offset to 0, so the resolution can be restarted.

- (nullable NSProgress *)resolveWith:(nullable id<OCProgressResolver>)resolver context:(nullable OCProgressResolutionContext)context; //!< Thread-safe resolution that can be called repeatedly. If resolver is nil, uses OCProgressManager.sharedProgressManager. If .progress is non-nil, immediately returns the object and bypasses resolution.

- (nullable NSProgress *)resolveWith:(nullable id<OCProgressResolver>)resolver; //!< Short-hand for -[resolveWith:resolver context:nil].

- (void)cancel; //!< Calls cancellationHandler if one is set. Otherwise calls [.progress cancel].

@end

NS_ASSUME_NONNULL_END
