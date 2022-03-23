//
//  OCDataConverter.m
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

#import "OCDataConverter.h"
#import "NSError+OCError.h"

@implementation OCDataConverter

- (instancetype)initWithInputType:(OCDataItemType)inputType outputType:(OCDataItemType)outputType conversion:(OCDataConversion)conversion
{
	if ((self = [super init]) != nil)
	{
		_inputType = inputType;
		_outputType = outputType;
		_conversion = [conversion copy];
	}

	return (self);
}

- (id)convert:(id)input renderer:(OCDataRenderer *)renderer error:(NSError * _Nullable __autoreleasing *)outError withOptions:(OCDataViewOptions)options
{
	if (_conversion == nil)
	{
		if (outError != NULL)
		{
			*outError = OCError(OCErrorFeatureNotImplemented);
		}

		return (nil);
	}

	return (_conversion(self, input, renderer, outError, options));
}

@end
