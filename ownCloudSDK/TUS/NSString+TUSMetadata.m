//
//  NSString+TUSMetadata.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 29.04.20.
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

#import "NSString+TUSMetadata.h"

@implementation NSString (TUSMetadata)

+ (nullable OCTUSMetadataString)stringFromTUSMetadata:(nullable OCTUSMetadata)metadata
{
	NSMutableString *mdString = nil;

	if (metadata.count > 0)
	{
		mdString = [NSMutableString new];

		[metadata enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull value, BOOL * _Nonnull stop) {
			if (![value isEqual:OCTUSMetadataNilValue])
			{
				NSString *base64EncodedValue;

				if ((base64EncodedValue = [[value dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]) != nil)
				{
					[mdString appendFormat:(mdString.length > 0) ? @",%@ %@" : @"%@ %@", key, base64EncodedValue];
				}
			}
			else
			{
				[mdString appendFormat:(mdString.length > 0) ? @",%@" : @"%@", key];
			}
		}];
	}

	return (mdString);
}

- (OCTUSMetadata)tusMetadata
{
	NSMutableDictionary<NSString*,NSString*> *metadata = nil;
	NSArray<NSString *> *keyValuePairs = [self componentsSeparatedByString:@","];

	if ((keyValuePairs != nil) && (keyValuePairs.count > 0))
	{
		metadata = [NSMutableDictionary new];

		for (NSString *keyValuePair in keyValuePairs)
		{
			NSArray<NSString *> *splitPair = [keyValuePair componentsSeparatedByString:@" "];
			NSString *splitPairKey = splitPair[0];
			NSString *splitPairValue = nil;

			if (splitPair.count == 1)
			{
				splitPairValue = OCTUSMetadataNilValue;
			}
			else
			{
				NSString *base64EncodedValue;

				if ((base64EncodedValue = splitPair[1]) != nil)
				{
					NSData *utf8Value = [[NSData alloc] initWithBase64EncodedString:base64EncodedValue options:NSDataBase64DecodingIgnoreUnknownCharacters];
					splitPairValue = [[NSString alloc] initWithData:utf8Value encoding:NSUTF8StringEncoding];
				}
			}

			metadata[splitPairKey] = splitPairValue;
		}
	}

	return (metadata);
}

@end

NSString *OCTUSMetadataNilValue = @"";

OCTUSMetadataKey OCTUSMetadataKeyFileName = @"filename";
OCTUSMetadataKey OCTUSMetadataKeyChecksum = @"checksum";

