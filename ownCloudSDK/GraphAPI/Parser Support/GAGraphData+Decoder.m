//
//  GAGraphData+Decoder.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 26.01.22.
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

#import "GAGraphData+Decoder.h"
#import "NSError+OCError.h"
#import "GAGraphObject.h"
#import "NSDate+OCDateParser.h"
#import "OCLogger.h"

@implementation NSDictionary (GAGraphDataDecoder)

- (nullable id)objectForKey:(NSString *)key ofClass:(Class)class inCollection:(nullable Class)collectionClass required:(BOOL)required context:(nullable GAGraphContext *)context error:(NSError * _Nullable * _Nullable)outError
{
	return ([NSDictionary object:self[key] key:key ofClass:class inCollection:collectionClass required:required context:context error:outError]);
}

+ (nullable id)object:(id)inObject key:(NSString *)key ofClass:(Class)class inCollection:(nullable Class)collectionClass required:(BOOL)required context:(nullable GAGraphContext *)context error:(NSError * _Nullable * _Nullable)outError
{
	id object = inObject;

	if (object != nil)
	{
		if (collectionClass != Nil)
		{
			if ([object isKindOfClass:collectionClass] && (class != collectionClass))
			{
				NSArray *collectionObject = (NSArray *)object;
				NSMutableArray *decodedCollection = [NSMutableArray new];

				for (id subObject in collectionObject)
				{
					id decodedObject;

					if ((decodedObject = [self object:subObject key:key ofClass:class inCollection:nil required:required context:context error:outError]) != nil)
					{
						[decodedCollection addObject:decodedObject];
					}
				}

				return (decodedCollection);
			}
		}

		if ([object isKindOfClass:class])
		{
			// Correct type
			return (object);
		}
		else if ([object isKindOfClass:NSString.class] && [class isSubclassOfClass:NSDate.class])
		{
			// Parse date
			NSDate *decodedDate;
			static dispatch_once_t onceToken;
			static NSISO8601DateFormatter *dateFormatter;
			static NSISO8601DateFormatter *dateFormatter2;

			dispatch_once(&onceToken, ^{
				dateFormatter = [NSISO8601DateFormatter new];
				dateFormatter.formatOptions = NSISO8601DateFormatWithInternetDateTime |
							      NSISO8601DateFormatWithDashSeparatorInDate |
							      NSISO8601DateFormatWithColonSeparatorInTime |
							      NSISO8601DateFormatWithColonSeparatorInTimeZone |
							      NSISO8601DateFormatWithFractionalSeconds;

				dateFormatter2 = [NSISO8601DateFormatter new];
				dateFormatter2.formatOptions = NSISO8601DateFormatWithInternetDateTime |
							       NSISO8601DateFormatWithDashSeparatorInDate |
							       NSISO8601DateFormatWithColonSeparatorInTime |
							       NSISO8601DateFormatWithColonSeparatorInTimeZone;
			});

			if ((decodedDate = [dateFormatter dateFromString:(NSString *)object]) != nil)
			{
				// with fractional seconds
				return (decodedDate);
			}
			else if ((decodedDate = [dateFormatter2 dateFromString:(NSString *)object]) != nil)
			{
				// without fractional seconds
				return (decodedDate);
			}
			else
			{
				OCLogError(@"GAGraphData+Decoder: error decoding date string %@", object);
			}
		}
		else if ([object isKindOfClass:NSString.class] && [class isSubclassOfClass:NSURL.class])
		{
			// Convert string to URL
			NSURL *url;
			if ((url = [NSURL URLWithString:(NSString *)object]) == nil)
			{
				// Implement fallback in case of unescaped URLs (https://github.com/owncloud/ocis/issues/3538)
				url = [NSURL URLWithString:[(NSString *)object stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet]];
			}

			if (url != nil)
			{
				// Block file URLs
				if (url.isFileURL)
				{
					OCLogError(@"GAGraphData+Decoder: converted %@ to URL, but it was a fileURL. Dropped conversion for security considerations.", url);
					return (nil);
				}
				return (url);
			}
		}
		else if ([object isKindOfClass:NSDictionary.class] && [class conformsToProtocol:@protocol(GAGraphObject)])
		{
			// Try parsing as GAGraphObject
			id decodedObject;

			if ((decodedObject = [((Class<GAGraphObject>)class) decodeGraphData:object context:nil error:outError]) != nil)
			{
				return (decodedObject);
			}
		}

		if (outError != NULL)
		{
			if (*outError == nil)
			{
				*outError = OCErrorWithDescription(OCErrorInvalidType, ([NSString stringWithFormat:@"Expected type %@ for key %@, got %@.", NSStringFromClass(class), key, NSStringFromClass([object class])]));
			}
		}
	}

	if (required)
	{
		if (outError != NULL)
		{
			if (*outError == nil)
			{
				*outError = OCErrorWithDescription(OCErrorRequiredValueMissing, ([NSString stringWithFormat:@"Required value missing for key %@ (type %@).", key, NSStringFromClass(class)]));
			}
		}
	}

	return (nil);
}

@end
