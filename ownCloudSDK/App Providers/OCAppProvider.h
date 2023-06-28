//
//  OCAppProvider.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.09.22.
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

#import <Foundation/Foundation.h>

typedef NSString* OCAppProviderAPIVersion;
typedef NSString* OCAppProviderKey NS_TYPED_ENUM;
typedef NSArray<NSDictionary<OCAppProviderKey,id> *> *OCAppProviderAppList;

@class OCAppProviderApp;
@class OCAppProviderFileType;

NS_ASSUME_NONNULL_BEGIN

@interface OCAppProvider : NSObject

@property(assign) BOOL enabled;

@property(strong,nullable) OCAppProviderAPIVersion version;
@property(nonatomic,assign) BOOL isSupported; //!< Computed property indicating if the API version is supported by the SDK

@property(strong,nullable) NSString *appsURLPath; //!< relative URL providing a list of available apps and their corresponding types
@property(strong,nullable) NSString *openURLPath; //!< relative URL to open a file (GET/POST/…)
@property(strong,nullable) NSString *openWebURLPath; //!< relative URL to open a file using web (GET only)
@property(strong,nullable) NSString *createURLPath; //!< relative URL to create a new file (newURL, needs to be named createURL due to compiler-enforced Cocoa naming conventions)

@property(readonly,nonatomic) BOOL supportsOpen;
@property(readonly,nonatomic) BOOL supportsOpenDirect;
@property(readonly,nonatomic) BOOL supportsOpenInWeb;
@property(readonly,nonatomic) BOOL supportsCreateDocument;

@property(strong,nullable,nonatomic) OCAppProviderAppList appList; //!< Raw app list as returned from the server. Setting this property parses the list and generates OCAppProviderApp and OCAppProviderFileType instances

@property(strong,nullable,readonly) NSArray<OCAppProviderApp *> *apps; //!< OCAppProviderApp instances created from the raw .appList
@property(strong,nullable,readonly) NSArray<OCAppProviderFileType *> *types; //!< OCAppProviderFileType instances created from the raw .appList

@end

// Keys as described at https://owncloud.dev/services/app-registry/apps/#listing-available-apps--mime-types
extern OCAppProviderKey OCAppProviderKeyMIMEType; //!< corresponds to key "mime_type" (string)
extern OCAppProviderKey OCAppProviderKeyExtension; //!< corresponds to key "ext" (string)
extern OCAppProviderKey OCAppProviderKeyName; //!< corresponds to key "name" (string)
extern OCAppProviderKey OCAppProviderKeyIcon; //!< corresponds to key "icon" (string)
extern OCAppProviderKey OCAppProviderKeyDescription; //!< corresponds to key "description" (string)
extern OCAppProviderKey OCAppProviderKeyAllowCreation; //!< corresponds to key "allow_creation" (bool)
extern OCAppProviderKey OCAppProviderKeyDefaultApplication; //!< corresponds to key "default_application" (string)
extern OCAppProviderKey OCAppProviderKeyAppProviders; //!< corresponds to key "app_providers" (array of dictionaries)

extern OCAppProviderKey OCAppProviderKeyAppProviderName; //!< corresponds to key app_providers[].name (string)
extern OCAppProviderKey OCAppProviderKeyAppProviderIcon; //!< corresponds to key app_providers[].icon (URL string)

NS_ASSUME_NONNULL_END
