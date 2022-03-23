//
//  OCDataRenderer.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 08.03.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCDataRenderer.h"
#import "OCDataConverter.h"
#import "NSError+OCError.h"

typedef NSString* OCDataItemTypePair;

@interface OCDataRenderer ()
{
	NSMutableDictionary<OCDataItemTypePair, OCDataConverter *> *_convertersByTypePair;
}
@end

@implementation OCDataRenderer

+ (instancetype)defaultRenderer
{
	static dispatch_once_t onceToken;
	static OCDataRenderer *defaultRenderer;

	dispatch_once(&onceToken, ^{
		defaultRenderer = [OCDataRenderer new];
	});

	return (defaultRenderer);

}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_convertersByTypePair = [NSMutableDictionary new];
	}

	return (self);
}

- (instancetype)initWithConverters:(NSArray<OCDataConverter *> *)converters
{
	if ((self = [self init]) != nil)
	{
		if (converters != nil)
		{
			[self addConverters:converters];
		}
	}

	return (self);
}

- (void)addConverters:(NSArray<OCDataConverter *> *)converters
{
	for (OCDataConverter *converter in converters)
	{
		OCDataItemTypePair pair = [converter.inputType stringByAppendingFormat:@":%@", converter.outputType];
		_convertersByTypePair[pair] = converter;
	}
}

- (OCDataConverter *)converterFrom:(OCDataItemType)inputType to:(OCDataItemType)outputType
{
	OCDataItemTypePair pair;

	if ((pair = [inputType stringByAppendingFormat:@":%@", outputType]) == nil)
	{
		return (nil);
	}

	return (_convertersByTypePair[pair]);
}

- (nullable id)renderObject:(id)object ofType:(OCDataItemType)inputType asType:(OCDataItemType)outputType error:(NSError * _Nullable * _Nullable)outError withOptions:(nullable OCDataViewOptions)options
{
	OCDataConverter *converter;

	// Catch lack of input type
	if (inputType == nil)
	{
		if (outError != NULL)
		{
			*outError = OCError(OCErrorDataItemTypeUnavailable);
		}

		return (nil);
	}

	// Find suitable converter
	if ((converter = [self converterFrom:inputType to:outputType]) != nil)
	{
		// Perform conversion
		return ([converter convert:object renderer:self error:outError withOptions:options]);
	}
	else
	{
		// No converter available for conversion from inputType to outputType
		if (outError != NULL)
		{
			*outError = OCError(OCErrorDataConverterUnavailable);
		}
	}

	return (nil);
}

- (nullable id)renderItem:(id<OCDataItem>)item asType:(OCDataItemType)outputType error:(NSError * _Nullable * _Nullable)outError withOptions:(nullable OCDataViewOptions)options
{
	OCDataItemType inputType;

	if ((inputType = item.dataItemType) != nil)
	{
		return ([self renderObject:item ofType:inputType asType:outputType error:outError withOptions:options]);
	}
	else
	{
		// Item does not return a dataItemType
		if (outError != NULL)
		{
			*outError = OCError(OCErrorDataItemTypeUnavailable);
		}
	}

	return (nil);
}

@end
