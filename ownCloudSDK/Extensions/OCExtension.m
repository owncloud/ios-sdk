//
//  OCExtension.m
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

#import "OCExtension.h"

@implementation OCExtension

+ (instancetype)extensionWithIdentifier:(OCExtensionIdentifier)identifier type:(OCExtensionType)type location:(OCExtensionLocationIdentifier)locationIdentifier features:(OCExtensionRequirements)features objectProvider:(OCExtensionObjectProvider)objectProvider
{
	return ([[self alloc] initWithIdentifier:identifier type:type location:locationIdentifier features:features objectProvider:objectProvider]);
}

- (instancetype)initWithIdentifier:(OCExtensionIdentifier)identifier type:(OCExtensionType)type location:(OCExtensionLocationIdentifier)locationIdentifier features:(OCExtensionRequirements)features objectProvider:(OCExtensionObjectProvider)objectProvider
{
	return ([self initWithIdentifier:identifier type:type locations:((locationIdentifier != nil) ? @[locationIdentifier] : nil) features:features objectProvider:objectProvider customMatcher:nil]);
}

- (instancetype)initWithIdentifier:(OCExtensionIdentifier)identifier type:(OCExtensionType)type locations:(NSArray <OCExtensionLocationIdentifier> *)locationIdentifiers features:(OCExtensionRequirements)features objectProvider:(OCExtensionObjectProvider)objectProvider customMatcher:(OCExtensionCustomContextMatcher)customMatcher
{
	if ((self = [super init]) != nil)
	{
		self.identifier = identifier;

		self.type = type;

		switch ([locationIdentifiers count])
		{
			case 1:
				self.locations = @[ [OCExtensionLocation locationOfType:type identifier:locationIdentifiers.firstObject] ];
			break;

			case 0:
			break;

			default: {
				NSMutableArray <OCExtensionLocation *> *locations = [NSMutableArray arrayWithCapacity:locationIdentifiers.count];

				for (OCExtensionLocationIdentifier locationIdentifier in locationIdentifiers)
				{
					[locations addObject:[OCExtensionLocation locationOfType:type identifier:locationIdentifier]];
				}

				self.locations = locations;
			}
			break;
		}

		self.features = features;
		self.objectProvider = objectProvider;
		self.customMatcher = customMatcher;
	}

	return(self);
}

- (OCExtensionPriority)matchesContext:(OCExtensionContext *)context
{
	OCExtensionPriority matchPriority = OCExtensionPriorityNoMatch;

	// Match type
	if ([context.location.type isEqual:self.type] || (context.location.type==nil))
	{
		matchPriority = OCExtensionPriorityTypeMatch;

		// If a location identifier is specified and locations are specified, they are required to match
		if ((context.location.identifier!=nil) && (_locations.count > 0))
		{
			BOOL matchedLocation = NO;

			for (OCExtensionLocation *location in _locations)
			{
				if ([location.identifier isEqual:context.location.identifier])
				{
					matchedLocation = YES;
					matchPriority = OCExtensionPriorityLocationMatch;
					break;
				}
			}

			if (!matchedLocation)
			{
				matchPriority = OCExtensionPriorityNoMatch;
				goto returnPriority;
			}
		}

		// Enforce requirements
		if ((context.requirements != nil) && (context.requirements.count > 0))
		{
			BOOL allRequirementsMet = YES;

			if (self.features == nil)
			{
				matchPriority = OCExtensionPriorityNoMatch;
				goto returnPriority;
			}

			for (id requirementKey in context.requirements)
			{
				if (![_features[requirementKey] isEqual:context.requirements[requirementKey]])
				{
					allRequirementsMet = NO;
				}
			}

			if (!allRequirementsMet)
			{
				matchPriority = OCExtensionPriorityNoMatch;
				goto returnPriority;
			}

			matchPriority = OCExtensionPriorityRequirementMatch;
		}

		// All requirements satisfied. Now check if we should return a fixed priority value.
		if (_priority != OCExtensionPriorityNoMatch)
		{
			// Return fixed priority value
			matchPriority = _priority;
		}
		else
		{
			// Add bonus for preferred features
			if ((context.preferences != nil) && (context.preferences.count > 0) && (self.features != nil))
			{
				for (id preferenceKey in context.preferences)
				{
					if ([_features[preferenceKey] isEqual:context.preferences[preferenceKey]])
					{
						matchPriority += OCExtensionPriorityFeatureMatchPlus;
					}
				}
			}
		}
	}

	// Return match priority
	returnPriority:

	// - Customize priority before return
	if (_customMatcher != nil)
	{
		matchPriority = _customMatcher(context, matchPriority);
	}

	return (matchPriority);
}

- (id)provideObjectForContext:(OCExtensionContext *)context
{
	id object = nil;

	if (_objectProvider != nil)
	{
		NSError *error = nil;

		object = _objectProvider(self, context, &error);
		context.error = error;
	}

	return (object);
}

@end

OCExtensionMetadataKey OCExtensionMetadataKeyName = @"name";
OCExtensionMetadataKey OCExtensionMetadataKeyDescription = @"description";
OCExtensionMetadataKey OCExtensionMetadataKeyVersion = @"version";
OCExtensionMetadataKey OCExtensionMetadataKeyCopyright = @"copyright";
