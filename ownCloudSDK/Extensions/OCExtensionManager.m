//
//  OCExtensionManager.m
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

#import "OCExtensionManager.h"

@implementation OCExtensionManager

@dynamic extensions;

+ (OCExtensionManager *)sharedExtensionManager
{
	static dispatch_once_t onceToken;
	static OCExtensionManager *sharedExtensionManager;

	dispatch_once(&onceToken, ^{
		sharedExtensionManager = [OCExtensionManager new];
	});

	return (sharedExtensionManager);
}

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_extensions = [NSMutableArray new];
	}

	return(self);
}

#pragma mark - Extension management
- (NSArray<OCExtension *> *)extensions
{
	@synchronized(self)
	{
		if (_cachedExtensions == nil)
		{
			_cachedExtensions = [[NSArray alloc] initWithArray:_extensions];
		}

		return (_cachedExtensions);
	}
}

- (BOOL)isExtensionAllowed:(OCExtension *)extension
{
	NSArray<OCExtensionIdentifier> *disallowedExtensionIdentifiers = [self classSettingForOCClassSettingsKey:OCClassSettingsKeyExtensionsDisallowed];

	if ([disallowedExtensionIdentifiers isKindOfClass:NSArray.class] && (extension.identifier != nil))
	{
		if ([disallowedExtensionIdentifiers containsObject:extension.identifier])
		{
			return (NO);
		}
	}

	return (YES);
}

- (void)addExtension:(OCExtension *)extension
{
	if (![self isExtensionAllowed:extension])
	{
		// Block disallowed extensions
		return;
	}

	@synchronized(self)
	{
		_cachedExtensions = nil;

		[_extensions addObject:extension];
	}
}

- (void)removeExtension:(OCExtension *)extension
{
	@synchronized(self)
	{
		_cachedExtensions = nil;

		[_extensions removeObjectIdenticalTo:extension];
	}
}

#pragma mark - Matching
- (nullable NSArray <OCExtensionMatch *> *)provideExtensionsForContext:(OCExtensionContext *)context error:(NSError * _Nullable *)outError
{
	NSMutableArray <OCExtensionMatch *> *matches = nil;

	@synchronized(self)
	{
		for (OCExtension *extension in _extensions)
		{
			OCExtensionPriority priority;

			// Block disallowed extensions
			if (![self isExtensionAllowed:extension]) { continue; }

			if ((priority = [extension matchesContext:context]) != OCExtensionPriorityNoMatch)
			{
				OCExtensionMatch *match;

				if ((match = [[OCExtensionMatch alloc] initWithExtension:extension priority:priority]) != nil)
				{
					if (matches == nil) {  matches = [NSMutableArray new]; }
					[matches addObject:match];
				}
			}
		}

		// Make matches with higher priority rank first
		[matches sortUsingDescriptors:@[ [NSSortDescriptor sortDescriptorWithKey:@"priority" ascending:NO]]];
	}

	return (matches);
}

- (void)provideExtensionsForContext:(OCExtensionContext *)context completionHandler:(void(^)(NSError * _Nullable error, OCExtensionContext *context, NSArray <OCExtensionMatch *> * _Nullable))completionHandler
{
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
		NSError *error = nil;
		NSArray <OCExtensionMatch *> *matches = nil;

		matches = [self provideExtensionsForContext:context error:&error];

		completionHandler(error, context, matches);
	});
}

#pragma mark - Class settings
+ (OCClassSettingsIdentifier)classSettingsIdentifier
{
	return (OCClassSettingsIdentifierExtensions);
}

+ (nullable NSDictionary<OCClassSettingsKey,id> *)defaultSettingsForIdentifier:(nonnull OCClassSettingsIdentifier)identifier
{
	return (@{
		OCClassSettingsKeyExtensionsDisallowed : @[],
	});
}

+ (BOOL)includeInLogSnapshot
{
	return (YES);
}

+ (OCClassSettingsMetadataCollection)classSettingsMetadata
{
	NSMutableDictionary<NSString*,NSString*> *possibleValues = [NSMutableDictionary new];

	for (OCExtension *extension in OCExtensionManager.sharedExtensionManager.extensions)
	{
		if (extension.identifier != nil)
		{
			possibleValues[extension.identifier] = [NSString stringWithFormat:@"Extension with the identifier %@.", extension.identifier];
		}
	}

	if (possibleValues.count == 0)
	{
		// Do not provide an empty possibleValues dictionary, because that results in a catch-22:
		// - on launch, OCClassSettings would use OCClassSettingsMetadataKeyPossibleValues to validate the set MDM/branding parameters
		// - the extensions, however, are only added later, so that the initial possible values are empty, which will effectively block the parameters usage/intention

		possibleValues = nil;
	}

	OCClassSettingsMetadataCollection metadata = @{
		OCClassSettingsKeyExtensionsDisallowed : [NSDictionary dictionaryWithObjectsAndKeys:
			OCClassSettingsMetadataTypeStringArray, 							OCClassSettingsMetadataKeyType,
			@"List of all disallowed extensions. If provided, extensions not listed here are allowed.", 	OCClassSettingsMetadataKeyDescription,
			@"Extensions", 											OCClassSettingsMetadataKeyCategory,
			OCClassSettingsKeyStatusAdvanced, 								OCClassSettingsMetadataKeyStatus,
			possibleValues,											OCClassSettingsMetadataKeyPossibleValues,
		nil]
	};

	return (metadata);
}

@end

OCClassSettingsIdentifier OCClassSettingsIdentifierExtensions = @"extensions";
OCClassSettingsKey OCClassSettingsKeyExtensionsDisallowed = @"disallowed";
