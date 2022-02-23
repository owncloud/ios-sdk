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
#import "OCConnection+OData.h"
#import "GAIdentitySet.h"
#import "GADrive.h"
#import "GAODataError.h"
#import "GAODataErrorMain.h"
#import "GAGraphData+Decoder.h"
#import "OCMacros.h"

@implementation OCConnection (GraphAPI)

- (NSArray<OCDrive *> *)drives
{
	@synchronized (_drivesByID)
	{
		return (_drives);
	}
}

- (void)setDrives:(NSArray<OCDrive *> *)drives
{
	NSMutableDictionary<OCDriveID, OCDrive *> *drivesByID = [NSMutableDictionary new];

	for (OCDrive *drive in drives)
	{
		if (drive.identifier != nil)
		{
			drivesByID[drive.identifier] = drive;
		}
	}

	@synchronized (_drivesByID)
	{
		_drives = drives;
		[_drivesByID setDictionary:drivesByID];
	}
}

- (OCDrive *)driveWithID:(OCDriveID)driveID
{
	@synchronized (_drivesByID)
	{
		return (_drivesByID[driveID]);
	}
}

- (void)driveWithID:(OCDriveID)driveID completionHandler:(void (^)(OCDrive * _Nullable))completionHandler
{
	OCDrive *drive;

	if ((drive = [self driveWithID:driveID]) != nil)
	{
		completionHandler(drive);
	}
	else
	{
		[self retrieveDriveListWithCompletionHandler:^(NSError * _Nullable error, NSArray<OCDrive *> * _Nullable drives) {
			if (drives.count > 0)
			{
				self.drives = drives;
			}

			completionHandler([self driveWithID:driveID]);
		}];
	}
}

- (nullable NSProgress *)retrieveDriveListWithCompletionHandler:(OCRetrieveDriveListCompletionHandler)completionHandler
{
	return ([self requestODataAtURL:[self URLForEndpoint:OCConnectionEndpointIDGraphMeDrives options:nil] requireSignals:[NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable] selectEntityID:nil selectProperties:nil filterString:nil entityClass:GADrive.class completionHandler:^(NSError * _Nullable error, id  _Nullable response) {
		NSMutableArray<OCDrive *> *ocDrives = nil;

		if (error == nil)
		{
			// Convert GADrives to OCDrives
			NSArray<GADrive *> *gaDrives;

			if ((gaDrives = OCTypedCast(response, NSArray)) != nil)
			{
				ocDrives = [NSMutableArray new];

				for (GADrive *drive in gaDrives)
				{
					OCDrive *ocDrive;

					if ((ocDrive = [OCDrive driveFromGDrive:drive]) != nil)
					{
						[ocDrives addObject:ocDrive];
					}
				}
			}
		}

		OCLogDebug(@"Drives response: drives=%@, error=%@", ocDrives, error);

		completionHandler(error, (ocDrives.count > 0) ? ocDrives : nil);
	}]);
}

@end

OCConnectionEndpointID OCConnectionEndpointIDGraphMeDrives = @"meDrives";
OCConnectionEndpointID OCConnectionEndpointIDGraphDrives = @"drives";

