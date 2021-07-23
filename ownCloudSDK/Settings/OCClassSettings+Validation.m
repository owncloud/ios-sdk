//
//  OCClassSettings+Validation.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.10.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCClassSettings+Validation.h"
#import "OCClassSettings+Metadata.h"
#import "NSError+OCClassSettings.h"
#import "OCMacros.h"

@implementation OCClassSettings (Validation)

- (id)_validateValue:(id)value forType:(OCClassSettingsMetadataType)type
{
	if ([type isEqual:OCClassSettingsMetadataTypeBoolean])
	{
		// Conversion
		if ([value isEqual:@"0"]) 	{ value = @(0); }
		if ([value isEqual:@"1"]) 	{ value = @(1); }
		if ([value isEqual:@"false"]) 	{ value = @(0); }
		if ([value isEqual:@"true"]) 	{ value = @(1); }

		// Validation
		if ([value isEqual:@(0)] ||
		    [value isEqual:@(1)])
		{
			return (value);
		}
	}

	if ([type isEqual:OCClassSettingsMetadataTypeInteger])
	{
		// Conversion
		if ([value isKindOfClass:NSString.class])
		{
			NSNumber *convertedNumber = @([(NSString *)value integerValue]);
			if ([convertedNumber.stringValue isEqual:value])
			{
				value = convertedNumber;
			}
		}

		// Validation
		if ([value isKindOfClass:NSNumber.class])
		{
			NSNumber *integerNumber = @([((NSNumber *)value) integerValue]);

			if ([integerNumber isEqualToNumber:value])
			{
				return (value);
			}
		}
	}

	if ([type isEqual:OCClassSettingsMetadataTypeFloat])
	{
		// Conversion
		if ([value isKindOfClass:NSString.class])
		{
			value = @([(NSString *)value doubleValue]);
		}

		// Validation
		if ([value isKindOfClass:NSNumber.class])
		{
			return (value);
		}
	}

	if ([type isEqual:OCClassSettingsMetadataTypeDate])
	{
		// Validation
		if ([value isKindOfClass:NSDate.class])
		{
			return (value);
		}
	}

	if ([type isEqual:OCClassSettingsMetadataTypeString])
	{
		// Validation
		if ([value isKindOfClass:NSString.class])
		{
			return (value);
		}
	}

	if ([type isEqual:OCClassSettingsMetadataTypeStringArray])
	{
		// Validation
		if ([value isKindOfClass:NSArray.class])
		{
			NSArray *checkArray = value;

			for (id object in checkArray)
			{
				if (![object isKindOfClass:NSString.class])
				{
					return (nil);
				}
			}

			return (value);
		}
	}

	if ([type isEqual:OCClassSettingsMetadataTypeURLString])
	{
		// Validation
		if ([value isKindOfClass:NSString.class])
		{
			return ([NSURL URLWithString:value]);
		}

		if ([value isKindOfClass:NSURL.class])
		{
			return (value);
		}
	}

	if ([type isEqual:OCClassSettingsMetadataTypeNumberArray])
	{
		// Validation
		if ([value isKindOfClass:NSArray.class])
		{
			NSArray *checkArray = value;

			for (id object in checkArray)
			{
				if (![object isKindOfClass:NSNumber.class])
				{
					return (nil);
				}
			}

			return (value);
		}
	}

	if ([type isEqual:OCClassSettingsMetadataTypeArray])
	{
		// Validation
		if ([value isKindOfClass:NSArray.class])
		{
			return (value);
		}
	}

	if ([type isEqual:OCClassSettingsMetadataTypeDictionary])
	{
		// Validation
		if ([value isKindOfClass:NSDictionary.class])
		{
			return (value);
		}
	}

	if ([type isEqual:OCClassSettingsMetadataTypeDictionaryArray])
	{
		// Validation
		if ([value isKindOfClass:NSArray.class])
		{
			NSArray *checkArray = value;

			for (id object in checkArray)
			{
				if (![object isKindOfClass:NSDictionary.class])
				{
					return (nil);
				}
			}

			return (value);
		}
	}

	return (nil); // No type match
}

- (BOOL)_autoExpand:(id)value withPossibleValue:(id)possibleValue autoExpansion:(OCClassSettingsAutoExpansion)autoExpansion
{
	if ([autoExpansion isEqual:OCClassSettingsAutoExpansionTrailing])
	{
		if ([value isKindOfClass:NSString.class] && [possibleValue isKindOfClass:NSString.class])
		{
			return ([(NSString *)possibleValue hasSuffix:(NSString *)value]);
		}
	}

	return (NO);
}

- (id)_validatedValue:(id)value forPossibleValues:(id)possibleValues ofSettingsIdentifier:(OCClassSettingsIdentifier)settingsIdentifier key:(OCClassSettingsKey)key autoExpansion:(OCClassSettingsAutoExpansion)autoExpansion error:(NSError **)outError
{
	NSError *error = nil;
	NSDictionary<id, NSString *> *descriptionByPossibleValues;
	NSArray<OCClassSettingsMetadata> *possibleValueRecords;
	id returnValue = nil;

	if ((descriptionByPossibleValues = OCTypedCast(possibleValues, NSDictionary)) != nil)
	{
		// Keys represent possible values, and the value is the description (f.ex. { @"allow-all" : @"Allows all.", … })
		if ([descriptionByPossibleValues objectForKey:value] != nil)
		{
			returnValue = value;
		}
		else
		{
			if (autoExpansion != nil)
			{
				for (id possibleValue in descriptionByPossibleValues)
				{
					if ([self _autoExpand:value withPossibleValue:possibleValue autoExpansion:autoExpansion])
					{
						returnValue = possibleValue;
						break;
					}
				}
			}
		}
	}
	else if ((possibleValueRecords = OCTypedCast(possibleValues, NSArray)) != nil)
	{
		// Array of dictionaries (f.ex. [ { OCClassSettingsMetadataKeyValue : @"allow-all", OCClassSettingsMetadataKeyDescription : @"Allows all." }, … ])
		for (OCClassSettingsMetadata record in possibleValueRecords)
		{
			id possibleValue = record[OCClassSettingsMetadataKeyValue];

			if ([possibleValue isEqual:value])
			{
				returnValue = value;
				break;
			}
		}

		if ((returnValue == nil) && (autoExpansion != nil))
		{
			for (OCClassSettingsMetadata record in possibleValueRecords)
			{
				id possibleValue;

				if ((possibleValue = record[OCClassSettingsMetadataKeyValue]) != nil)
				{
					if ([self _autoExpand:value withPossibleValue:possibleValue autoExpansion:autoExpansion])
					{
						returnValue = possibleValue;
						break;
					}
				}
			}
		}
	}

	if (returnValue == nil)
	{
		error = [NSError errorWithDomain:OCClassSettingsErrorDomain code:OCClassSettingsErrorCodeInvalidValue userInfo:@{
			NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Value %@ not allowed for %@.%@", value, settingsIdentifier, key]
		}];
	}

	if (error != nil)
	{
		*outError = error;
	}

	return (returnValue);
}

- (void)validateValue:(id)value forClass:(Class<OCClassSettingsSupport>)settingsClass key:(OCClassSettingsKey)key resultHandler:(void(^)(NSError * _Nullable error, id _Nullable value))resultHandler
{
	NSError *error = nil;
	id resultValue = value;
	OCClassSettingsMetadata metadata;
	Class<OCClassSettingsSupport> validationClass = settingsClass;
	OCClassSettingsIdentifier settingsIdentifier = [settingsClass classSettingsIdentifier];

	// Metadata validation
	if ((metadata = [self metadataForClass:settingsClass key:key options:nil]) != nil)
	{
		// Type validation
		OCClassSettingsMetadataType expectedType = nil;
		NSArray<OCClassSettingsMetadataType>* allowedTypes = nil;

		if ((expectedType = OCTypedCast(metadata[OCClassSettingsMetadataKeyType], NSString)) != nil)
		{
			if ((resultValue = [self _validateValue:value forType:expectedType]) == nil)
			{
				error = [NSError errorWithDomain:OCClassSettingsErrorDomain code:OCClassSettingsErrorCodeInvalidType userInfo:@{
					NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Type %@ of value %@ not allowed for %@.%@ (expected: %@)", NSStringFromClass([value class]), value, settingsIdentifier, key, expectedType]
				}];
			}
		}
		else if ((allowedTypes = OCTypedCast(metadata[OCClassSettingsMetadataKeyType], NSArray)) != nil)
		{
			resultValue = nil;

			for (OCClassSettingsMetadataType type in allowedTypes)
			{
				if ((resultValue = [self _validateValue:value forType:type]) != nil)
				{
					break;
				}
			}

			if (resultValue == nil)
			{
				error = [NSError errorWithDomain:OCClassSettingsErrorDomain code:OCClassSettingsErrorCodeInvalidType userInfo:@{
					NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Type %@ of value %@ not allowed for %@.%@ (expected: one of %@)", NSStringFromClass([value class]), value, settingsIdentifier, key, allowedTypes]
				}];
			}
		}

		// Possible value validation
		if (error == nil)
		{
			id possibleValues;

			if ((possibleValues = metadata[OCClassSettingsMetadataKeyPossibleValues]) != nil)
			{
				if ([resultValue isKindOfClass:NSArray.class])
				{
					NSMutableArray *resultArray = [NSMutableArray new];

					for (id element in (NSArray *)resultValue)
					{
						id validatedValue;

						if ((validatedValue = [self _validatedValue:element forPossibleValues:possibleValues ofSettingsIdentifier:settingsIdentifier key:key autoExpansion:metadata[OCClassSettingsMetadataKeyAutoExpansion] error:&error]) != nil)
						{
							[resultArray addObject:validatedValue];
						}
						else
						{
							resultValue = nil;
							break;
						}
					}

					if (resultValue != nil)
					{
						resultValue = resultArray;
					}
				}
				else
				{
					resultValue = [self _validatedValue:resultValue forPossibleValues:possibleValues ofSettingsIdentifier:settingsIdentifier key:key autoExpansion:metadata[OCClassSettingsMetadataKeyAutoExpansion] error:&error];
				}
			}
		}

		// Custom Validation Class
		NSString *validationClassName;

		if ((validationClassName = metadata[OCClassSettingsMetadataKeyCustomValidationClass]) != nil)
		{
			validationClass = NSClassFromString(validationClassName);
		}
	}

	// Custom validation
	if ((error == nil) && (validationClass != Nil))
	{
		if ([validationClass respondsToSelector:@selector(validateValue:forSettingsKey:)])
		{
			error = [validationClass validateValue:resultValue forSettingsKey:key];
		}
	}

	resultHandler(error, resultValue);
}

- (nullable NSDictionary<OCClassSettingsKey, NSError *> *)validateDictionary:(NSMutableDictionary<OCClassSettingsKey, id> *)settingsDict forClass:(Class<OCClassSettingsSupport>)settingsClass updateCache:(BOOL)updateCacheOfValidValues
{
	__block NSMutableDictionary<OCClassSettingsKey, NSError *> *errorsByKey = nil;
	NSArray<OCClassSettingsKey> *keys = [settingsDict allKeys];
	OCClassSettingsIdentifier settingsIdentifier = [settingsClass classSettingsIdentifier];

	@synchronized(_validatedValuesByKeyByIdentifier)
	{
		if (_validatedValuesByKeyByIdentifier[settingsIdentifier] == nil)
		{
			_validatedValuesByKeyByIdentifier[settingsIdentifier] = [NSMutableDictionary new];
		}

		if (_actualValuesByKeyByIdentifier[settingsIdentifier] == nil)
		{
			_actualValuesByKeyByIdentifier[settingsIdentifier] = [NSMutableDictionary new];
		}
	}

	for (OCClassSettingsKey key in keys)
	{
		BOOL needsValidation = YES;

		@synchronized(_validatedValuesByKeyByIdentifier)
		{
			// Check if the value has previously been checked and found valid
			if ([_validatedValuesByKeyByIdentifier[settingsIdentifier][key] isEqual:settingsDict[key]])
			{
				// Use validated result and avoid (much more expensive) validation
				settingsDict[key] = _actualValuesByKeyByIdentifier[settingsIdentifier][key];
				needsValidation = NO;
			}
		}

		if (needsValidation)
		{
			// Validate value
			id inputValue = settingsDict[key];

			[self validateValue:inputValue forClass:settingsClass key:key resultHandler:^(NSError * _Nullable error, id  _Nullable value) {
				if (error != nil)
				{
					if (errorsByKey == nil)
					{
						errorsByKey = [NSMutableDictionary new];
					}

					errorsByKey[key] = error;
				}

				// Update settings dictionary with validated value
				settingsDict[key] = value;

				if (updateCacheOfValidValues)
				{
					@synchronized(self->_validatedValuesByKeyByIdentifier)
					{
						// Store validated value and validation result - clear on errors
						self->_validatedValuesByKeyByIdentifier[settingsIdentifier][key] = (error == nil) ? inputValue : nil;
						self->_actualValuesByKeyByIdentifier[settingsIdentifier][key] = (error == nil) ? value : nil;
					}
				}
			}];
		}
	}

	return (errorsByKey);
}

@end
