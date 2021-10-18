//
//  OCCapabilities.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.03.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCCapabilities.h"
#import "OCMacros.h"
#import "OCConnection.h"

static NSInteger _defaultSharingSearchMinLength = 2;

@interface OCCapabilities()
{
	NSDictionary<NSString *, id> *_capabilities;

	OCTUSHeader *_tusCapabilitiesHeader;
	NSArray<OCTUSVersion> *_tusVersions;
	NSArray<OCTUSExtension> *_tusExtensions;
}

@end

@implementation OCCapabilities

#pragma mark - Version
@dynamic majorVersion;
@dynamic minorVersion;
@dynamic microVersion;

#pragma mark - Core
@dynamic pollInterval;
@dynamic webDAVRoot;

#pragma mark - Core : Status
@dynamic installed;
@dynamic maintenance;
@dynamic needsDBUpgrade;
@dynamic version;
@dynamic versionString;
@dynamic edition;
@dynamic productName;
@dynamic hostName;
@dynamic supportedChecksumTypes;
@dynamic preferredUploadChecksumType;
@dynamic longProductVersionString;

#pragma mark - DAV
@dynamic davChunkingVersion;
@dynamic davReports;
@dynamic davPropfindSupportsDepthInfinity;

#pragma mark - TUS
@dynamic tusSupported;
@dynamic tusCapabilities;
@dynamic tusVersions;
@dynamic tusResumable;
@dynamic tusExtensions;
@dynamic tusMaxChunkSize;
@dynamic tusHTTPMethodOverride;

@dynamic tusCapabilitiesHeader;

#pragma mark - Files
@dynamic supportsPrivateLinks;
@dynamic supportsBigFileChunking;
@dynamic blacklistedFiles;
@dynamic supportsUndelete;
@dynamic supportsVersioning;

#pragma mark - Sharing
@dynamic sharingAPIEnabled;
@dynamic sharingResharing;
@dynamic sharingGroupSharing;
@dynamic sharingAutoAcceptShare;
@dynamic sharingWithGroupMembersOnly;
@dynamic sharingWithMembershipGroupsOnly;
@dynamic sharingAllowed;
@dynamic sharingDefaultPermissions;
@dynamic sharingSearchMinLength;

#pragma mark - Sharing : Public
@dynamic publicSharingEnabled;
@dynamic publicSharingPasswordEnforced;
@dynamic publicSharingPasswordEnforcedForReadOnly;
@dynamic publicSharingPasswordEnforcedForReadWrite;
@dynamic publicSharingPasswordEnforcedForUploadOnly;
@dynamic publicSharingExpireDateEnabled;
@dynamic publicSharingExpireDateEnforced;
@dynamic publicSharingDefaultExpireDateDays;
@dynamic publicSharingSendMail;
@dynamic publicSharingSocialShare;
@dynamic publicSharingUpload;
@dynamic publicSharingMultiple;
@dynamic publicSharingSupportsUploadOnly;
@dynamic publicSharingDefaultLinkName;

#pragma mark - Sharing : User
@dynamic userSharingSendMail;

#pragma mark - Sharing : User Enumeration
@dynamic userEnumerationEnabled;
@dynamic userEnumerationGroupMembersOnly;

#pragma mark - Sharing : Federation
@dynamic federatedSharingIncoming;
@dynamic federatedSharingOutgoing;

#pragma mark - Notifications
@dynamic notificationEndpoints;

- (instancetype)initWithRawJSON:(NSDictionary<NSString *,id> *)rawJSON
{
	if ((self = [super init]) != nil)
	{
		_rawJSON = rawJSON;
		_capabilities = _rawJSON[@"ocs"][@"data"][@"capabilities"];
	}

	return (self);
}

#pragma mark - Helpers
- (NSNumber *)_castOrConvertToNumber:(id)value
{
	if ([value isKindOfClass:[NSString class]])
	{
		value = @([((NSString *)value) longLongValue]);
	}

	return (OCTypedCast(value, NSNumber));
}

#pragma mark - Version
- (NSNumber *)majorVersion
{
	return (OCTypedCast(_rawJSON[@"ocs"][@"data"][@"version"][@"major"], NSNumber));
}

- (NSNumber *)minorVersion
{
	return (OCTypedCast(_rawJSON[@"ocs"][@"data"][@"version"][@"minor"], NSNumber));
}

- (NSNumber *)microVersion
{
	return (OCTypedCast(_rawJSON[@"ocs"][@"data"][@"version"][@"micro"], NSNumber));
}

#pragma mark - Core
- (NSNumber *)pollInterval
{
	return (OCTypedCast(_capabilities[@"core"][@"pollinterval"], NSNumber));
}

- (NSString *)webDAVRoot
{
	return (OCTypedCast(_capabilities[@"core"][@"webdav-root"], NSString));
}

#pragma mark - Core : Status
- (OCCapabilityBool)installed
{
	return (OCTypedCast(_capabilities[@"core"][@"status"][@"installed"], NSNumber));
}

- (OCCapabilityBool)maintenance
{
	return (OCTypedCast(_capabilities[@"core"][@"status"][@"maintenance"], NSNumber));
}

- (OCCapabilityBool)needsDBUpgrade
{
	return (OCTypedCast(_capabilities[@"core"][@"status"][@"needsDbUpgrade"], NSNumber));
}

- (NSString *)version
{
	return (OCTypedCast(_capabilities[@"core"][@"status"][@"version"], NSString));
}

- (NSString *)versionString
{
	return (OCTypedCast(_capabilities[@"core"][@"status"][@"versionstring"], NSString));
}

- (NSString *)edition
{
	return (OCTypedCast(_capabilities[@"core"][@"status"][@"edition"], NSString));
}

- (NSString *)productName
{
	return (OCTypedCast(_capabilities[@"core"][@"status"][@"productname"], NSString));
}

- (NSString *)hostName
{
	return (OCTypedCast(_capabilities[@"core"][@"status"][@"hostname"], NSString));
}

- (NSString *)longProductVersionString
{
	NSDictionary *statusDict;

	if ((statusDict = OCTypedCast(_capabilities[@"core"][@"status"], NSDictionary)) != nil)
	{
		return ([OCConnection serverLongProductVersionStringFromServerStatus:statusDict]);
	}

	return (nil);
}

#pragma mark - Checksums
- (NSArray<OCChecksumAlgorithmIdentifier> *)supportedChecksumTypes
{
	return (OCTypedCast(_capabilities[@"checksums"][@"supportedTypes"], NSArray));
}

- (OCChecksumAlgorithmIdentifier)preferredUploadChecksumType
{
	return (OCTypedCast(_capabilities[@"checksums"][@"preferredUploadType"], NSString));
}

#pragma mark - DAV
- (NSString *)davChunkingVersion
{
	return (OCTypedCast(_capabilities[@"dav"][@"chunking"], NSString));
}

- (NSArray<NSString *> *)davReports
{
	return (OCTypedCast(_capabilities[@"dav"][@"reports"], NSArray));
}

- (OCCapabilityBool)davPropfindSupportsDepthInfinity
{
	return (OCTypedCast(_capabilities[@"dav"][@"propfind"][@"depth_infinity"], NSNumber));
}

#pragma mark - TUS
- (BOOL)tusSupported
{
	return (self.tusResumable.length > 0);
}

- (OCTUSCapabilities)tusCapabilities
{
	return (OCTypedCast(_capabilities[@"files"][@"tus_support"], NSDictionary));
}

- (NSArray<OCTUSVersion> *)tusVersions
{
	if (_tusVersions)
	{
		_tusVersions = [OCTypedCast(self.tusCapabilities[@"version"], NSString) componentsSeparatedByString:@","];
	}

	return (_tusVersions);
}

- (OCTUSVersion)tusResumable
{
	return(OCTypedCast(self.tusCapabilities[@"resumable"], NSString));
}

- (NSArray<OCTUSExtension> *)tusExtensions
{
	if (_tusExtensions == nil)
	{
		NSString *tusExtensionsString = OCTypedCast(self.tusCapabilities[@"extension"], NSString);

		_tusExtensions = [tusExtensionsString componentsSeparatedByString:@","];
	}

	return (_tusExtensions);
}

- (NSNumber *)tusMaxChunkSize
{
	return(OCTypedCast(self.tusCapabilities[@"max_chunk_size"], NSNumber));
}

- (OCHTTPMethod)tusHTTPMethodOverride
{
	NSString *httpMethodOverride = OCTypedCast(self.tusCapabilities[@"http_method_override"], NSString);

	if (httpMethodOverride.length == 0)
	{
		return (nil);
	}

	return(httpMethodOverride);
}

- (OCTUSHeader *)tusCapabilitiesHeader
{
	if ((_tusCapabilitiesHeader == nil) && self.tusSupported)
	{
		OCTUSHeader *header = [[OCTUSHeader alloc] init];

		header.extensions = self.tusExtensions;
		header.version = self.tusResumable;
		header.versions = self.tusVersions;

		header.maximumChunkSize = self.tusMaxChunkSize;

		_tusCapabilitiesHeader = header;
	}

	return (_tusCapabilitiesHeader);
}

#pragma mark - Files
- (OCCapabilityBool)supportsPrivateLinks
{
	return (OCTypedCast(_capabilities[@"files"][@"privateLinks"], NSNumber));
}

- (OCCapabilityBool)supportsBigFileChunking
{
	return (OCTypedCast(_capabilities[@"files"][@"bigfilechunking"], NSNumber));
}

- (NSArray <NSString *> *)blacklistedFiles
{
	return (OCTypedCast(_capabilities[@"files"][@"blacklisted_files"], NSArray));
}

- (OCCapabilityBool)supportsUndelete
{
	return (OCTypedCast(_capabilities[@"files"][@"undelete"], NSNumber));
}

- (OCCapabilityBool)supportsVersioning
{
	return (OCTypedCast(_capabilities[@"files"][@"versioning"], NSNumber));
}

#pragma mark - Sharing
- (OCCapabilityBool)sharingAPIEnabled
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"api_enabled"], NSNumber));
}

- (OCCapabilityBool)sharingResharing
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"resharing"], NSNumber));
}

- (OCCapabilityBool)sharingGroupSharing
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"group_sharing"], NSNumber));
}

- (OCCapabilityBool)sharingAutoAcceptShare
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"auto_accept_share"], NSNumber));
}

- (OCCapabilityBool)sharingWithGroupMembersOnly
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"share_with_group_members_only"], NSNumber));
}

- (OCCapabilityBool)sharingWithMembershipGroupsOnly
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"share_with_membership_groups_only"], NSNumber));
}

- (OCCapabilityBool)sharingAllowed
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"can_share"], NSNumber));
}

- (OCSharePermissionsMask)sharingDefaultPermissions
{
	return ((OCTypedCast(_capabilities[@"files_sharing"][@"default_permissions"], NSNumber)).integerValue);
}

- (NSNumber *)sharingSearchMinLength
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"search_min_length"], NSNumber));
}

+ (NSInteger)defaultSharingSearchMinLength
{
	return _defaultSharingSearchMinLength;
}

#pragma mark - Sharing : Public
- (OCCapabilityBool)publicSharingEnabled
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"public"][@"enabled"], NSNumber));
}

- (OCCapabilityBool)publicSharingPasswordEnforced
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"public"][@"password"][@"enforced"], NSNumber));
}

- (OCCapabilityBool)publicSharingPasswordEnforcedForReadOnly
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"public"][@"password"][@"enforced_for"][@"read_only"], NSNumber));
}

- (OCCapabilityBool)publicSharingPasswordEnforcedForReadWrite
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"public"][@"password"][@"enforced_for"][@"read_write"], NSNumber));
}

- (OCCapabilityBool)publicSharingPasswordEnforcedForUploadOnly
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"public"][@"password"][@"enforced_for"][@"upload_only"], NSNumber));
}

- (OCCapabilityBool)publicSharingExpireDateEnabled
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"public"][@"expire_date"][@"enabled"], NSNumber));
}

- (OCCapabilityBool)publicSharingExpireDateEnforced
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"public"][@"expire_date"][@"enforced"], NSNumber));
}

- (NSNumber *)publicSharingDefaultExpireDateDays
{
	return ([self _castOrConvertToNumber:_capabilities[@"files_sharing"][@"public"][@"expire_date"][@"days"]]);
}

- (OCCapabilityBool)publicSharingSendMail
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"public"][@"send_mail"], NSNumber));
}

- (OCCapabilityBool)publicSharingSocialShare
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"public"][@"social_share"], NSNumber));
}

- (OCCapabilityBool)publicSharingUpload
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"public"][@"upload"], NSNumber));
}

- (OCCapabilityBool)publicSharingMultiple
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"public"][@"multiple"], NSNumber));
}

- (OCCapabilityBool)publicSharingSupportsUploadOnly
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"public"][@"supports_upload_only"], NSNumber));
}

- (NSString *)publicSharingDefaultLinkName
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"public"][@"defaultPublicLinkShareName"], NSString));
}

#pragma mark - Sharing : User
- (OCCapabilityBool)userSharingSendMail
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"user"][@"send_mail"], NSNumber));
}

#pragma mark - Sharing : User Enumeration
- (OCCapabilityBool)userEnumerationEnabled
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"user_enumeration"][@"enabled"], NSNumber));
}

- (OCCapabilityBool)userEnumerationGroupMembersOnly
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"user_enumeration"][@"group_members_only"], NSNumber));
}

#pragma mark - Sharing : Federation
- (OCCapabilityBool)federatedSharingIncoming
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"federation"][@"incoming"], NSNumber));
}

- (OCCapabilityBool)federatedSharingOutgoing
{
	return (OCTypedCast(_capabilities[@"files_sharing"][@"federation"][@"outgoing"], NSNumber));
}

#pragma mark - Notifications
- (NSArray<NSString *> *)notificationEndpoints
{
	return (OCTypedCast(_capabilities[@"notifications"][@"ocs-endpoints"], NSArray));
}

@end
