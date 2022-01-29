//
//  GAGraphData+Decoder.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 26.01.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

#import "GAGraphData+Decoder.h"
#import "NSError+OCError.h"
#import "GAGraphObject.h"
#import "NSDate+OCDateParser.h"

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

			dispatch_once(&onceToken, ^{
				dateFormatter = [NSISO8601DateFormatter new];
				dateFormatter.formatOptions = NSISO8601DateFormatWithInternetDateTime |
							      NSISO8601DateFormatWithDashSeparatorInDate |
							      NSISO8601DateFormatWithColonSeparatorInTime |
							      NSISO8601DateFormatWithColonSeparatorInTimeZone |
							      NSISO8601DateFormatWithFractionalSeconds;
			});

			if ((decodedDate = [dateFormatter dateFromString:(NSString *)object]) != nil)
			{
				return (decodedDate);
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
