//
//  OCODataResponse.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 16.12.24.
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

#import "OCODataResponse.h"

@implementation OCODataResponse

- (nonnull instancetype)initWithError:(nullable NSError *)error result:(nullable id)result libreGraphObjects:(nullable OCODataLibreGraphObjects)libreGraphObjects
{
	if ((self = [super init]) != nil)
	{
		_error = error;
		_result = result;
		_libreGraphObjects = libreGraphObjects;
	}

	return (self);
}

@end
