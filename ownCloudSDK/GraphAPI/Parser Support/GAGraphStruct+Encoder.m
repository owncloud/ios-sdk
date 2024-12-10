//
//  GAGraphStruct+Encoder.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.11.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "GAGraphStruct+Encoder.h"
#import "NSError+OCError.h"
#import "GAGraphObject.h"
#import "NSDate+OCDateParser.h"
#import "OCLogger.h"
#import "OCMacros.h"
#import "GAGraphContext.h"

@implementation NSMutableDictionary (GAGraphDataEncoder)

- (id)_encodeValue:(id)value required:(BOOL)required context:(GAGraphContext *)context error:(NSError **)outError
{
	NSError *error = nil;
	NSArray *array = nil;
	NSDictionary *dict = nil;

	// Encode graph objects
	if ([value conformsToProtocol:@protocol(GAGraphObject)]) {
		// Invoke graph struct encoding for graph objects
		value = [(id<GAGraphObject>)value encodeToGraphStructWithContext:context error:&error];

		if (error != nil)
		{
			*outError = error;
			return (nil);
		}

		return (value);
	}

	// Encode arrays
	if ((array = OCTypedCast(value, NSArray)) != nil) {
		// Iterate through arrays
		NSMutableArray *encodedValues = [[NSMutableArray alloc] initWithCapacity:array.count];

		for (id obj in array)
		{
			id encodedValue = [self _encodeValue:obj required:required context:context error:&error];

			if (error != nil) {
				*outError = error;
				return (nil);
			}

			if (encodedValue != nil)
			{
				[encodedValues addObject:encodedValue];
			}
		}

		return (encodedValues);
	}

	// Encode dictionaries
	if ((dict = OCTypedCast(value, NSDictionary)) != nil) {
		// Iterate through dictionaries
		NSMutableDictionary *encodedDict = [[NSMutableDictionary alloc] initWithCapacity:dict.count];

		for (NSString *key in dict)
		{
			id value = dict[key];
			id encodedValue = [self _encodeValue:value required:required context:context error:&error];

			if (error != nil)
			{
				*outError = error;
				return (nil);
			}

			encodedDict[key] = encodedValue;
		}

		return (encodedDict);
	}

	// Convert standard types
	NSURL *urlVal;
	if ((urlVal = OCTypedCast(value, NSURL)) != nil) {
		// URL -> convert to string
		return (urlVal.absoluteString);
	}

	NSDate *dateVal;
	if ((dateVal = OCTypedCast(value, NSDate)) != nil) {
		// Date -> convert to ISO8601
		static dispatch_once_t onceToken;
		static NSISO8601DateFormatter *dateFormatter;

		dispatch_once(&onceToken, ^{
			dateFormatter = [NSISO8601DateFormatter new];
			dateFormatter.formatOptions = NSISO8601DateFormatWithInternetDateTime |
						      NSISO8601DateFormatWithDashSeparatorInDate |
						      NSISO8601DateFormatWithColonSeparatorInTime |
						      NSISO8601DateFormatWithColonSeparatorInTimeZone |
						      NSISO8601DateFormatWithFractionalSeconds;
		});

		return ([dateFormatter stringFromDate:dateVal]);
	}

	return (value);
}

- (nullable NSError *)set:(nullable id<NSObject>)value forKey:(NSString *)key required:(BOOL)required context:(GAGraphContext *)context
{
	NSError *error = nil;

	if (required && (value == nil) &&
	    ((context == nil) || ((context != nil) && !context.ignoreRequirements))
	   )
	{
		return (OCErrorWithDescription(OCErrorRequiredValueMissing, ([NSString stringWithFormat:@"GAGraphDataEncoder: missing value for required property %@", key])));
	}

	id encodedValue = [self _encodeValue:value required:key context:context error:&error];

	if (error != nil)
	{
		return (error);
	}

	if (required && (encodedValue == nil) &&
	    ((context == nil) || ((context != nil) && !context.ignoreConversionErrors))
	   )
	{
		return (OCErrorWithDescription(OCErrorRequiredValueMissing, ([NSString stringWithFormat:@"GAGraphDataEncoder: conversion failed for required property %@=%@", key, value])));
	}

	if (encodedValue != nil)
	{
		[self setObject:encodedValue forKey:key];
	}

	return (error);
}

@end
