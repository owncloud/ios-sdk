//
//  OCServerLocatorLookupTable.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 08.11.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCServerLocatorLookupTable.h"
#import "OCMacros.h"
#import "NSError+OCError.h"
#import "OCExtensionManager.h"
#import "OCExtension+ServerLocator.h"

@implementation OCServerLocatorLookupTable

#pragma mark - Class settings
+ (void)load
{
	// Register server locator extension
	[OCExtensionManager.sharedExtensionManager addExtension:[OCExtension serverLocatorExtensionWithIdentifier:OCServerLocatorIdentifierLookupTable locations:@[] metadata:@{
		OCExtensionMetadataKeyDescription : @"Locate server via lookup table. Keys can match against the beginning (f.ex. \"begins:bob@\"), end (f.ex. \"ends:@owncloud.org\") or regular expression (f.ex. \"regexp:\")"
	} provider:^OCServerLocator * _Nullable(OCExtension * _Nonnull extension, OCExtensionContext * _Nonnull context, NSError * _Nullable __autoreleasing * _Nullable error) {
		return ([self new]);
	}]];

	// Register class setting defauls and metadata
	[self registerOCClassSettingsDefaults:@{
	} metadata:@{
		OCClassSettingsKeyServerLocatorLookupTable : @{
			OCClassSettingsMetadataKeyType		: OCClassSettingsMetadataTypeDictionary,
			OCClassSettingsMetadataKeyDescription	: @"Lookup table that maps users to server URLs",
			OCClassSettingsMetadataKeyStatus	: OCClassSettingsKeyStatusAdvanced,
			OCClassSettingsMetadataKeyCategory	: @"Connection",
		}
	}];
}

- (NSError *)locate
{
	NSDictionary<NSString *, NSString *> *lookupTable;

	if ((lookupTable = [self classSettingForOCClassSettingsKey:OCClassSettingsKeyServerLocatorLookupTable]) != nil)
	{
		for (NSString *key in lookupTable)
		{
			BOOL matches = NO;

			if ([key hasPrefix:@"begins:"])
			{
				NSString *begins = [key substringFromIndex:7];

				if ([self.userName hasPrefix:begins])
				{
					matches = YES;
				}
			}
			else if ([key hasPrefix:@"ends:"])
			{
				NSString *ends = [key substringFromIndex:5];

				if ([self.userName hasSuffix:ends])
				{
					matches = YES;
				}
			}
			else if ([key hasPrefix:@"regex:"])
			{
				NSString *regex = [key substringFromIndex:6];
				NSError *error = nil;
				NSRegularExpression *regularExpression;

				regularExpression = [NSRegularExpression regularExpressionWithPattern:regex options:NSRegularExpressionCaseInsensitive error:&error];

				if (error != nil)
				{
					OCLogError(@"Invalid regular expression: %@", regex);
				}

				if ([regularExpression numberOfMatchesInString:self.userName options:0 range:NSMakeRange(0, self.userName.length)])
				{
					matches = YES;
				}
			}

			if (matches)
			{
				self.url = [NSURL URLWithString:lookupTable[key]];
				break;
			}
		}
	}

	return (nil);
}

@end

OCClassSettingsKey OCClassSettingsKeyServerLocatorLookupTable = @"lookup-table";
OCServerLocatorIdentifier OCServerLocatorIdentifierLookupTable = @"lookup-table";
