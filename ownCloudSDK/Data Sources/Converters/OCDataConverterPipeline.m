//
//  OCDataConverterPipeline.m
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

#import "OCDataConverterPipeline.h"

@implementation OCDataConverterPipeline

- (instancetype)initWithConverters:(NSArray<OCDataConverter *> *)converters
{
	if ((self = [super init]) != nil)
	{
		_converters = converters;
	}

	return (self);
}

- (OCDataItemType)inputType
{
	return (_converters.firstObject.inputType);
}

- (OCDataItemType)outputType
{
	return (_converters.lastObject.outputType);
}

- (id)convert:(id)originalInput renderer:(OCDataRenderer *)renderer error:(NSError * _Nullable __autoreleasing *)outError withOptions:(OCDataViewOptions)options
{
	id output = nil;
	id input = originalInput;

	for (OCDataConverter *converter in _converters)
	{
		NSError *converterError = nil;

		output = [converter convert:input renderer:renderer error:&converterError withOptions:options];

		// If a converter returns an error, no further conversion takes place - we return nil and the error directly
		if (converterError != nil)
		{
			if (outError != NULL)
			{
				*outError = converterError;
			}

			return (nil);
		}

		// If a converter returns nil, no further conversion takes place - we return nil directly
		if (output == nil)
		{
			return (nil);
		}

		input = output;
	}

	return (output);
}

@end
