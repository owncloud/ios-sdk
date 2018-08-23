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
	OCExtension *extension = [OCExtension new];

	extension.identifier = identifier;

	extension.type = type;

	if (locationIdentifier != nil)
	{
		extension.locations = @[ [OCExtensionLocation locationOfType:type identifier:locationIdentifier] ];
	}

	extension.features = features;
	extension.objectProvider = objectProvider;

	return (extension);
}

- (OCExtensionPriority)matchesContext:(OCExtensionContext *)context
{
	OCExtensionPriority matchPriority = OCExtensionPriorityNoMatch;

	// Match type
	if ([context.location.type isEqual:self.type])
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
				return (OCExtensionPriorityNoMatch);
			}
		}

		// Enforce requirements
		if ((context.requirements != nil) && (context.requirements.count > 0))
		{
			BOOL allRequirementsMet = YES;

			if (self.features == nil)
			{
				return (OCExtensionPriorityNoMatch);
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
				return (OCExtensionPriorityNoMatch);
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
					if (![_features[preferenceKey] isEqual:context.preferences[preferenceKey]])
					{
						matchPriority += OCExtensionPriorityFeatureMatchPlus;
					}
				}
			}
		}
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
