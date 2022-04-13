//
//  OCDrive.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 31.01.22.
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

#import "OCDrive.h"
#import "GADrive.h"
#import "GADriveItem.h"
#import "OCMacros.h"
#import "OCLocation.h"
#import "OCCore.h"
#import "NSError+OCError.h"
#import "NSProgress+OCExtensions.h"

#import "OCDataConverter.h"
#import "OCDataRenderer.h"
#import "OCDataItemPresentable.h"
#import "OCResourceManager.h"

#import "OCResourceRequestDriveItem.h"

@implementation OCDrive

+ (instancetype)driveFromGADrive:(GADrive *)gDrive
{
	OCDrive *drive = nil;

	if (gDrive != nil)
	{
		drive = [OCDrive new];

		drive.identifier = gDrive.identifier;
		drive.type = gDrive.driveType;

		drive.name = gDrive.name;
		drive.desc = gDrive.desc;

		drive.davRootURL = gDrive.root.webDavUrl;

		drive.quota = (OCQuota *)gDrive.quota;

		drive.gaDrive = gDrive;
	}

	return (drive);
}

+ (instancetype)personalDrive
{
	return(nil);
}

+ (void)load
{
	OCDataConverter *driveToPresentableConverter;

	driveToPresentableConverter = [[OCDataConverter alloc] initWithInputType:OCDataItemTypeDrive outputType:OCDataItemTypePresentable conversion:^id _Nullable(OCDataConverter * _Nonnull converter, OCDrive * _Nullable inDrive, OCDataRenderer * _Nullable renderer, NSError * _Nullable __autoreleasing * _Nullable outError, OCDataViewOptions  _Nullable options) {
		OCDataItemPresentable *presentable = nil;

		if (inDrive != nil)
		{
			GADriveItem *imageDriveItem = [inDrive.gaDrive specialDriveItemFor:GASpecialFolderNameImage];
			GADriveItem *readmeDriveItem = [inDrive.gaDrive specialDriveItemFor:GASpecialFolderNameReadme];

			presentable = [[OCDataItemPresentable alloc] initWithItem:inDrive];
			presentable.title = inDrive.name;
			presentable.subtitle = inDrive.type;

			presentable.availableResources = (imageDriveItem != nil) ?
								((readmeDriveItem != nil) ? 	@[OCDataItemPresentableResourceCoverImage, OCDataItemPresentableResourceCoverDescription] :
												@[OCDataItemPresentableResourceCoverImage]) :
								((readmeDriveItem != nil) ? 	@[OCDataItemPresentableResourceCoverDescription] :
												nil);

			presentable.resourceProvider = ^(OCDataItemPresentable * _Nonnull presentable, OCDataItemPresentableResource  _Nonnull resource, OCDataViewOptions  _Nullable options, void (^ _Nonnull completionHandler)(NSError * _Nullable, id _Nullable)) {
				OCCore *core;
				NSProgress *progress = NSProgress.indeterminateProgress;

				if ((core = options[OCDataViewOptionCore]) != nil)
				{
					OCResourceRequestDriveItem *resourceRequest = nil;
					GADriveItem *requestItem = nil;

					if ([resource isEqual:OCDataItemPresentableResourceCoverImage])
					{
						if (imageDriveItem != nil)
						{
							requestItem = imageDriveItem;
						}
						else
						{
							completionHandler(nil, nil);
						}
					}

					if ([resource isEqual:OCDataItemPresentableResourceCoverDescription])
					{
						if (readmeDriveItem != nil)
						{
							requestItem = readmeDriveItem;
						}
						else
						{
							completionHandler(nil, nil);
						}
					}

					if (requestItem != nil)
					{
						resourceRequest = [OCResourceRequestDriveItem requestDriveItem:requestItem waitForConnectivity:NO changeHandler:^(OCResourceRequest * _Nonnull request, NSError * _Nullable error, BOOL isOngoing, OCResource * _Nullable previousResource, OCResource * _Nullable newResource) {
							if (!isOngoing)
							{
								completionHandler(error, newResource);
							}
						}];
						resourceRequest.lifetime = OCResourceRequestLifetimeSingleRun;
					}

					if (resourceRequest != nil)
					{
						__weak OCResourceRequest *weakResourceRequest = resourceRequest;

						progress.cancellationHandler = ^{
							[weakResourceRequest endRequest];
						};

						[core.vault.resourceManager startRequest:resourceRequest];
					}
				}
				else
				{
					// Missing core in options
					completionHandler(OCError(OCErrorInsufficientParameters), nil);
				}

				return (progress);
			};
		}

		return (presentable);
	}];

	[OCDataRenderer.defaultRenderer addConverters:@[
		driveToPresentableConverter
	]];
}

- (BOOL)isSubstantiallyDifferentFrom:(OCDrive *)drive
{
	return (![drive.identifier isEqual:_identifier] ||
	 	![drive.type isEqual:_type] ||
	 	![drive.name isEqual:_name] ||
	 	![drive.desc isEqual:_desc] ||
	 	![drive.davRootURL isEqual:_davRootURL] ||
	 	(![drive.rootETag isEqual:self.rootETag] && (drive.rootETag != self.rootETag)));
}

- (OCLocation *)rootLocation
{
	return ([[OCLocation alloc] initWithDriveID:_identifier path:@"/"]);
}

- (OCFileETag)rootETag
{
	OCFileETag rootETag = _gaDrive.root.eTag;

	if (rootETag == nil)
	{
		rootETag = _gaDrive.eTag;
	}

	return (rootETag);
}

#pragma mark - Secure coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [self init]) != nil)
	{
		_identifier = [decoder decodeObjectOfClass:NSString.class forKey:@"identifier"];
		_type = [decoder decodeObjectOfClass:NSString.class forKey:@"type"];

		_name = [decoder decodeObjectOfClass:NSString.class forKey:@"name"];
		_desc = [decoder decodeObjectOfClass:NSString.class forKey:@"desc"];

		_davRootURL = [decoder decodeObjectOfClass:NSURL.class forKey:@"davURL"];

		_quota = [decoder decodeObjectOfClass:GAQuota.class forKey:@"quota"];

		_gaDrive = [decoder decodeObjectOfClass:GADrive.class forKey:@"gaDrive"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_identifier forKey:@"identifier"];
	[coder encodeObject:_type forKey:@"type"];

	[coder encodeObject:_name forKey:@"name"];
	[coder encodeObject:_desc forKey:@"desc"];

	[coder encodeObject:_davRootURL forKey:@"davURL"];

	[coder encodeObject:_quota forKey:@"quota"];

	[coder encodeObject:_gaDrive forKey:@"gaDrive"];
}

#pragma mark - OCDataItem / OCDataItemVersion compliance
- (OCDataItemType)dataItemType
{
	return (OCDataItemTypeDrive);
}

- (OCDataItemReference)dataItemReference
{
	return (_identifier);
}

- (OCDataItemVersion)dataItemVersion
{
	return ([NSString stringWithFormat:@"%@:%@:%@:%@:%@:%@", _identifier, _type, _name, _desc, _davRootURL, _gaDrive.eTag]);
}

#pragma mark - Comparison
- (NSUInteger)hash
{
	return (_identifier.hash ^ _gaDrive.eTag.hash ^ _name.hash ^ _desc.hash ^ _davRootURL.hash);
}

- (BOOL)isEqual:(id)object
{
	if ([object isKindOfClass:OCDrive.class])
	{
		return ([self isSubstantiallyDifferentFrom:object]);
	}

	return (NO);
}

#pragma mark - Description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p%@%@%@%@%@>", NSStringFromClass(self.class), self,
		OCExpandVar(identifier),
		OCExpandVar(type),
		OCExpandVar(name),
		OCExpandVar(quota),
		OCExpandVar(davRootURL)
	]);
}

@end

OCDriveType OCDriveTypePersonal = @"personal";
OCDriveType OCDriveTypeVirtual = @"virtual";
OCDriveType OCDriveTypeProject = @"project";
OCDriveType OCDriveTypeShare = @"share";
