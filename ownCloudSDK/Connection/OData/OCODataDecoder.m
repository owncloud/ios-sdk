//
//  OCODataDecoder.m
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

#import "OCODataDecoder.h"
#import "OCConnection+OData.h"
#import "GAODataError.h"
#import "NSError+OCError.h"
#import "OCODataResponse.h"
#import "OCMacros.h"

@implementation OCODataDecoder

- (instancetype)initWithLibreGraphID:(OCODataLibreGraphID)libreGraphID entityClass:(nullable Class)entityClass customDecoder:(nullable OCODataCustomDecoder)customDecoder
{
	if ((self = [super init]) != nil)
	{
		_libreGraphID = libreGraphID;
		_entityClass = entityClass;
		_customDecoder = [customDecoder copy];
	}

	return (self);
}

- (nullable id)decodeValue:(id)value error:(NSError * _Nullable * _Nullable)outError
{
	if (_customDecoder == nil)
	{
		OCODataResponse *decodedResponse = [OCODataDecoder decodeODataResponse:value entityClass:_entityClass options:nil];

		if (outError != NULL)
		{
			*outError = decodedResponse.error;
		}

		return (decodedResponse.result);
	}

	return self.customDecoder(value, outError);
}

+ (nullable OCODataResponse *)decodeODataResponse:(id)jsonObj entityClass:(nullable Class)entityClass options:(nullable OCODataOptions)options;
{
	NSMutableDictionary<OCODataLibreGraphID, id> *libreGraphObjects = nil;
	NSError *returnError = nil;
	id returnResult = nil;
	NSDictionary<NSString *, id> *jsonDictionary = OCTypedCast(jsonObj, NSDictionary);
	NSArray *jsonArray = OCTypedCast(jsonObj, NSArray);

	if (jsonDictionary != nil)
	{
		if (jsonDictionary[@"error"] != nil)
		{
			NSError *decodeError = nil;

			GAODataError *dataError = [jsonDictionary objectForKey:@"error" ofClass:GAODataError.class inCollection:Nil required:NO context:nil error:&decodeError];
			returnError = dataError.nativeError;
		}
		else if ((jsonDictionary[@"value"] != nil) && (entityClass != nil))
		{
			if ([jsonDictionary[@"value"] isKindOfClass:NSArray.class])
			{
				returnResult = [jsonDictionary objectForKey:@"value" ofClass:entityClass inCollection:NSArray.class required:NO context:nil error:&returnError];
			}
			else
			{
				returnResult = [jsonDictionary objectForKey:@"value" ofClass:entityClass inCollection:Nil required:NO context:nil error:&returnError];
			}
		}
		else if (entityClass != nil)
		{
			returnResult = [NSDictionary object:jsonDictionary key:nil ofClass:entityClass inCollection:Nil required:YES context:nil error:&returnError];
		}
		else
		{
			returnError = OCError(OCErrorResponseUnknownFormat);
		}

		if (returnError == nil)
		{
			NSArray<OCODataDecoder *> *decoders;
			if ((decoders = OCTypedCast(options[OCODataOptionKeyLibreGraphDecoders], NSArray)) != nil)
			{
				libreGraphObjects = [NSMutableDictionary new];

				for (OCODataDecoder *decoder in decoders)
				{
					if (jsonDictionary[decoder.libreGraphID] != nil)
					{
						NSError *decodeError = nil;

						id value = [decoder decodeValue:jsonDictionary[decoder.libreGraphID] error:&decodeError];

						if (decodeError != nil) {
							returnError = decodeError;
							break;
						}

						if (value != nil) {
							[libreGraphObjects setObject:value forKey:decoder.libreGraphID];
						}
					}
				}
			}
		}
	}
	else if (jsonArray != nil)
	{
		NSMutableArray *decodedObjects = [NSMutableArray new];
		for (id jsonObj in jsonArray)
		{
			id decodedObj = [NSDictionary object:jsonObj key:nil ofClass:entityClass inCollection:Nil required:YES context:nil error:&returnError];
			if (returnError != nil) { break; }
			if (decodedObj != nil) {
				[decodedObjects addObject:decodedObj];
			}
		}
		returnResult = decodedObjects;
	}
	else
	{
		returnError = OCError(OCErrorInvalidParameter);
	}

	OCLogDebug(@"OData response: returnResult=%@, error=%@, json: %@", returnResult, returnError, jsonDictionary);

	return ([[OCODataResponse alloc] initWithError:returnError result:returnResult libreGraphObjects:libreGraphObjects]);
}

@end

OCODataOptionKey OCODataOptionKeyLibreGraphDecoders = @"libreGraphDecoders";
