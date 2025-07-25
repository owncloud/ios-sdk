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
#import "GADeleted.h"
#import "GAIdentitySet.h"
#import "GAIdentity.h"
#import "OCIdentity+GraphAPI.h"
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

		drive.quota = gDrive.quota;

		drive.gaDrive = gDrive;
	}

	return (drive);
}

#pragma mark - OCDataConverter for OCDrives
+ (void)load
{
	OCDataConverter *driveToPresentableConverter;

	driveToPresentableConverter = [[OCDataConverter alloc] initWithInputType:OCDataItemTypeDrive outputType:OCDataItemTypePresentable conversion:^id _Nullable(OCDataConverter * _Nonnull converter, OCDrive * _Nullable inDrive, OCDataRenderer * _Nullable renderer, NSError * _Nullable __autoreleasing * _Nullable outError, OCDataViewOptions  _Nullable options) {
		OCDataItemPresentable *presentable = nil;
		__weak OCCore *weakCore = options[OCDataViewOptionCore];

		if (inDrive != nil)
		{
			GADriveItem *imageDriveItem = [inDrive.gaDrive specialDriveItemFor:GASpecialFolderNameImage];
			GADriveItem *readmeDriveItem = [inDrive.gaDrive specialDriveItemFor:GASpecialFolderNameReadme];

			presentable = [[OCDataItemPresentable alloc] initWithItem:inDrive];
			presentable.title = inDrive.name;
			presentable.subtitle = (inDrive.desc.length > 0) ? inDrive.desc : nil; // inDrive.type;

			presentable.availableResources = (imageDriveItem != nil) ?
								((readmeDriveItem != nil) ? 	@[OCDataItemPresentableResourceCoverImage, OCDataItemPresentableResourceCoverDescription] :
												@[OCDataItemPresentableResourceCoverImage]) :
								((readmeDriveItem != nil) ? 	@[OCDataItemPresentableResourceCoverDescription] :
												nil);

			presentable.resourceRequestProvider = ^OCResourceRequest * _Nullable(OCDataItemPresentable * _Nonnull presentable, OCDataItemPresentableResource  _Nonnull presentableResource, OCDataViewOptions  _Nullable options, NSError * _Nullable __autoreleasing * _Nullable outError) {
				OCResourceRequestDriveItem *resourceRequest = nil;

				if ([presentableResource isEqual:OCDataItemPresentableResourceCoverImage] && (imageDriveItem != nil))
				{
					resourceRequest = [OCResourceRequestDriveItem requestDriveItem:imageDriveItem waitForConnectivity:YES changeHandler:nil];
				}

				if ([presentableResource isEqual:OCDataItemPresentableResourceCoverDescription] && (readmeDriveItem != nil))
				{
					resourceRequest = [OCResourceRequestDriveItem requestDriveItem:readmeDriveItem waitForConnectivity:YES changeHandler:nil];
				}

				resourceRequest.lifetime = OCResourceRequestLifetimeSingleRun;
				resourceRequest.core = weakCore;

				return (resourceRequest);
			};
		}

		return (presentable);
	}];

	[OCDataRenderer.defaultRenderer addConverters:@[
		driveToPresentableConverter
	]];
}

#pragma mark - Comparison
- (BOOL)isSubstantiallyDifferentFrom:(OCDrive *)drive
{
	return (OCNANotEqual(drive.identifier, _identifier) ||
	 	OCNANotEqual(drive.type, _type) ||
	 	OCNANotEqual(drive.name, _name) ||
	 	OCNANotEqual(drive.desc, _desc) ||
	 	OCNANotEqual(drive.davRootURL, _davRootURL) ||
	 	OCNANotEqual([drive.gaDrive specialDriveItemFor:GASpecialFolderNameImage].eTag, [_gaDrive specialDriveItemFor:GASpecialFolderNameImage].eTag) ||
	 	OCNANotEqual([drive.gaDrive specialDriveItemFor:GASpecialFolderNameReadme].eTag, [_gaDrive specialDriveItemFor:GASpecialFolderNameReadme].eTag) ||
	 	OCNANotEqual(drive.detachedSinceDate, _detachedSinceDate) ||
	 	(drive.detachedState != _detachedState) ||
	 	(drive.isDisabled != self.isDisabled) ||
	 	OCNANotEqual(drive.rootETag, self.rootETag));
}

#pragma mark - Special types
- (OCDriveSpecialType)specialType
{
	// Personal space, identified by type
	if ([self.type isEqual:OCDriveTypePersonal])
	{
		return (OCDriveSpecialTypePersonal);
	}

	// Shares space, identified by UUID
	if ([self.identifier isEqual:OCDriveIDSharesJail])
	{
		return (OCDriveSpecialTypeShares);
	}

	// Project space, identified by type
	if ([self.type isEqual:OCDriveTypeProject])
	{
		return (OCDriveSpecialTypeSpace);
	}

	return (nil);
}

#pragma mark - Overrides
- (NSString *)name
{
	OCDriveSpecialType specialType = self.specialType;
	
	if (self.isKiteworksServer)
	{
		return (_name);
	}
	
	if ([specialType isEqual:OCDriveSpecialTypePersonal])
	{
		return (OCLocalizedString(@"Personal",nil));
	}
	
	if ([specialType isEqual:OCDriveSpecialTypeShares])
	{
		return (OCLocalizedString(@"Shared with me",nil));
	}

	return (_name);
}

#pragma mark - Utility accessors
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

- (BOOL)isDisabled
{
	return ([_gaDrive.root.deleted.state isEqual:GADeletedStateTrashed]);
}

- (NSArray<GAPermission *> *)permissions
{
	return (_gaDrive.root.permissions);
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

		_detachedState = [decoder decodeIntegerForKey:@"detachedState"];
		_detachedSinceDate = [decoder decodeObjectOfClass:NSDate.class forKey:@"detachedSinceDate"];
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

	[coder encodeInteger:_detachedState forKey:@"detachedState"];
	[coder encodeObject:_detachedSinceDate forKey:@"detachedSinceDate"];
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
	return ([NSString stringWithFormat:@"%@:%@:%@:%@:%@:%@:%@:%@:%ld:%@:%ld", _identifier, _type, _name, _desc, _davRootURL, _gaDrive.eTag, [_gaDrive specialDriveItemFor:GASpecialFolderNameImage].eTag, [_gaDrive specialDriveItemFor:GASpecialFolderNameReadme].eTag, (long)_detachedState, _detachedSinceDate, (long)self.isDisabled]);
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
	return ([NSString stringWithFormat:@"<%@: %p%@%@%@%@, isDetached: %d%@%@>", NSStringFromClass(self.class), self,
		OCExpandVar(identifier),
		OCExpandVar(type),
		OCExpandVar(name),
		[NSString stringWithFormat:@", rootETag: %@", self.rootETag],
		self.isDetached,
		OCExpandVar(quota),
		OCExpandVar(davRootURL)
	]);
}

@end

OCDriveType OCDriveTypePersonal = @"personal";
OCDriveType OCDriveTypeVirtual = @"virtual";
OCDriveType OCDriveTypeProject = @"project";
OCDriveType OCDriveTypeMountpoint = @"mountpoint";
OCDriveType OCDriveTypeShare = @"share";

OCDriveSpecialType OCDriveSpecialTypePersonal = @"personal";
OCDriveSpecialType OCDriveSpecialTypeShares = @"shares";
OCDriveSpecialType OCDriveSpecialTypeSpace = @"space";

OCDriveProperty OCDrivePropertyName = @"name"; // Must correspond to GADriveUpdate key path
OCDriveProperty OCDrivePropertyDescription = @"desc"; // Must correspond to GADriveUpdate key path
OCDriveProperty OCDrivePropertyQuotaTotal = @"quota.total"; // Must correspond to GADriveUpdate key path

OCDriveTemplate OCDriveTemplateDefault = @"default";

OCDriveResource OCDriveResourceCoverImage = @"image";
OCDriveResource OCDriveResourceCoverDescription = @"description";
OCDriveResource OCDriveResourceSpaceFolder = @"space-folder";

OCDriveID OCDriveIDSharesJail = @"a0ca6a90-a365-4782-871e-d44447bbc668$a0ca6a90-a365-4782-871e-d44447bbc668";
