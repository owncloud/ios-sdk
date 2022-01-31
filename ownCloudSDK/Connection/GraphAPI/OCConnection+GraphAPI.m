//
//  OCConnection+GraphAPI.m
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

#import "OCConnection+GraphAPI.h"
#import "GAIdentitySet.h"
#import "GADrive.h"
#import "GAODataError.h"
#import "GAODataErrorMain.h"
#import "GAGraphData+Decoder.h"

@implementation OCConnection (GraphAPI)

- (nullable NSProgress *)retrieveDriveListWithCompletionHandler:(OCRetrieveDriveListCompletionHandler)completionHandler
{
	OCHTTPRequest *request;
	NSProgress *progress = nil;

	request = [OCHTTPRequest requestWithURL:[self URLForEndpoint:OCConnectionEndpointIDGraphDrives options:nil]];
	request.requiredSignals = self.actionSignals;
//
//	[request setValue:@"json" forParameter:@"format"];

	progress = [self sendRequest:request ephermalCompletionHandler:^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
		NSError *jsonError = nil;
		NSArray<OCDrive *> *drives = nil;

		if (error == nil)
		{
			NSDictionary <NSString *, id> *jsonDictionary;

			if ((jsonDictionary = [response bodyConvertedDictionaryFromJSONWithError:&jsonError]) != nil)
			{
				if (jsonDictionary[@"error"])
				{
					NSError *decodeError = nil;

					GAODataError *dataError = [jsonDictionary objectForKey:@"error" ofClass:GAODataError.class inCollection:Nil required:NO context:nil error:&decodeError];
					error = dataError.nativeError;
				}
				else if (jsonDictionary[@"value"])
				{
					NSArray<OCDrive *> *gaDrives;

					if ((gaDrives = [jsonDictionary objectForKey:@"value" ofClass:GADrive.class inCollection:NSArray.class required:NO context:nil error:&error]) != nil)
					{
						NSMutableArray<OCDrive *> *ocDrives = [NSMutableArray new];

						for (GADrive *drive in gaDrives)
						{
							OCDrive *ocDrive;

							if ((ocDrive = [OCDrive driveFromGDrive:drive]) != nil)
							{
								[ocDrives addObject:ocDrive];
							}
						}

						if (ocDrives.count > 0)
						{
							drives = ocDrives;
						}
					}
				}

				OCLogDebug(@"Drives response: drives=%@, error=%@, json: %@", drives, error, jsonDictionary);
			}
			else
			{
				if (jsonError != nil)
				{
					error = jsonError;
				}
			}
		}

		completionHandler(error, drives);
	}];

	return (progress);
}

@end

OCConnectionEndpointID OCConnectionEndpointIDGraphDrives = @"drives";
