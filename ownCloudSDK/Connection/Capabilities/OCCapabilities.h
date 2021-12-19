//
//  OCCapabilities.h
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

#import <Foundation/Foundation.h>
#import "OCChecksumAlgorithm.h"
#import "OCShare.h"
#import "OCTUSHeader.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSNumber* OCCapabilityBool;

@interface OCCapabilities : NSObject

#pragma mark - Version
@property(readonly,nullable,nonatomic) NSNumber *majorVersion;
@property(readonly,nullable,nonatomic) NSNumber *minorVersion;
@property(readonly,nullable,nonatomic) NSNumber *microVersion;

#pragma mark - Core
@property(readonly,nullable,nonatomic) NSNumber *pollInterval;
@property(readonly,nullable,nonatomic) NSString *webDAVRoot;

#pragma mark - Core : Status
@property(readonly,nullable,nonatomic) OCCapabilityBool installed;
@property(readonly,nullable,nonatomic) OCCapabilityBool maintenance;
@property(readonly,nullable,nonatomic) OCCapabilityBool needsDBUpgrade;
@property(readonly,nullable,nonatomic) NSString *version;
@property(readonly,nullable,nonatomic) NSString *versionString;
@property(readonly,nullable,nonatomic) NSString *edition;
@property(readonly,nullable,nonatomic) NSString *productName;
@property(readonly,nullable,nonatomic) NSString *hostName;

@property(readonly,nullable,nonatomic) NSString *longProductVersionString;

#pragma mark - Checksums
@property(readonly,nullable,nonatomic) NSArray<OCChecksumAlgorithmIdentifier> *supportedChecksumTypes;
@property(readonly,nullable,nonatomic) OCChecksumAlgorithmIdentifier preferredUploadChecksumType;

#pragma mark - DAV
@property(readonly,nullable,nonatomic) NSString *davChunkingVersion;
@property(readonly,nullable,nonatomic) NSArray<NSString *> *davReports;
@property(readonly,nullable,nonatomic) OCCapabilityBool davPropfindSupportsDepthInfinity;

#pragma mark - TUS
@property(readonly,nonatomic) BOOL tusSupported;
@property(readonly,nullable,nonatomic) OCTUSCapabilities tusCapabilities;
@property(readonly,nullable,nonatomic) NSArray<OCTUSVersion> *tusVersions;
@property(readonly,nullable,nonatomic) OCTUSVersion tusResumable;
@property(readonly,nullable,nonatomic) NSArray<OCTUSExtension> *tusExtensions;
@property(readonly,nullable,nonatomic) NSNumber *tusMaxChunkSize;
@property(readonly,nullable,nonatomic) OCHTTPMethod tusHTTPMethodOverride;

@property(readonly,nullable,nonatomic) OCTUSHeader *tusCapabilitiesHeader; //!< .tusCapabilities translated into an OCTUSHeader

#pragma mark - Files
@property(readonly,nullable,nonatomic) OCCapabilityBool supportsPrivateLinks;
@property(readonly,nullable,nonatomic) OCCapabilityBool supportsBigFileChunking;
@property(readonly,nullable,nonatomic) NSArray<NSString *> *blacklistedFiles;
@property(readonly,nullable,nonatomic) OCCapabilityBool supportsUndelete;
@property(readonly,nullable,nonatomic) OCCapabilityBool supportsVersioning;

#pragma mark - Sharing
@property(readonly,nullable,nonatomic) OCCapabilityBool sharingAPIEnabled;
@property(readonly,nullable,nonatomic) OCCapabilityBool sharingResharing;
@property(readonly,nullable,nonatomic) OCCapabilityBool sharingGroupSharing;
@property(readonly,nullable,nonatomic) OCCapabilityBool sharingAutoAcceptShare;
@property(readonly,nullable,nonatomic) OCCapabilityBool sharingWithGroupMembersOnly;
@property(readonly,nullable,nonatomic) OCCapabilityBool sharingWithMembershipGroupsOnly;
@property(readonly,nullable,nonatomic) OCCapabilityBool sharingAllowed;
@property(readonly,nonatomic) OCSharePermissionsMask sharingDefaultPermissions;
@property(readonly,nullable,nonatomic) NSNumber *sharingSearchMinLength;
@property(readonly,class,nonatomic) NSInteger defaultSharingSearchMinLength;

#pragma mark - Sharing : Public
@property(readonly,nullable,nonatomic) OCCapabilityBool publicSharingEnabled;
@property(readonly,nullable,nonatomic) OCCapabilityBool publicSharingPasswordEnforced;
@property(readonly,nullable,nonatomic) OCCapabilityBool publicSharingPasswordEnforcedForReadOnly;
@property(readonly,nullable,nonatomic) OCCapabilityBool publicSharingPasswordEnforcedForReadWrite;
@property(readonly,nullable,nonatomic) OCCapabilityBool publicSharingPasswordEnforcedForUploadOnly;
@property(readonly,nullable,nonatomic) OCCapabilityBool publicSharingExpireDateEnabled;
@property(readonly,nullable,nonatomic) OCCapabilityBool publicSharingExpireDateEnforced;
@property(readonly,nullable,nonatomic) NSNumber *publicSharingDefaultExpireDateDays;
@property(readonly,nullable,nonatomic) OCCapabilityBool publicSharingSendMail;
@property(readonly,nullable,nonatomic) OCCapabilityBool publicSharingSocialShare;
@property(readonly,nullable,nonatomic) OCCapabilityBool publicSharingUpload;
@property(readonly,nullable,nonatomic) OCCapabilityBool publicSharingMultiple;
@property(readonly,nullable,nonatomic) OCCapabilityBool publicSharingSupportsUploadOnly;
@property(readonly,nullable,nonatomic) NSString *publicSharingDefaultLinkName;

#pragma mark - Sharing : User
@property(readonly,nullable,nonatomic) OCCapabilityBool userSharingSendMail;

#pragma mark - Sharing : User Enumeration
@property(readonly,nullable,nonatomic) OCCapabilityBool userEnumerationEnabled;
@property(readonly,nullable,nonatomic) OCCapabilityBool userEnumerationGroupMembersOnly;

#pragma mark - Sharing : Federation
@property(readonly,nullable,nonatomic) OCCapabilityBool federatedSharingIncoming;
@property(readonly,nullable,nonatomic) OCCapabilityBool federatedSharingOutgoing;

#pragma mark - Notifications
@property(readonly,nullable,nonatomic) NSArray<NSString *> *notificationEndpoints;

#pragma mark - Raw JSON
@property(readonly,strong) NSDictionary<NSString *, id> *rawJSON;

- (instancetype)initWithRawJSON:(NSDictionary<NSString *, id> *)rawJSON;

@end

NS_ASSUME_NONNULL_END
