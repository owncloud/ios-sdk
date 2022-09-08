//
//  OCAppProviderFileType.h
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
#import "OCTypes.h"
#import "OCResourceRequest.h"

@class OCAppProvider;
@class OCAppProviderApp;

typedef NSString* OCAppProviderAppName;

NS_ASSUME_NONNULL_BEGIN

@interface OCAppProviderFileType : NSObject

@property(weak,nullable) OCAppProvider *provider;

@property(strong,nullable) OCMIMEType mimeType;
@property(strong,nullable) OCFileExtension extension;

@property(strong,nullable) NSString *name;
@property(strong,nullable) NSURL *iconURL;
@property(strong,nullable) NSString *typeDescription;

@property(strong,nullable,nonatomic,readonly) OCResourceRequest *iconResourceRequest;
@property(strong,nullable,nonatomic,readonly) UIImage *icon;

@property(assign) BOOL allowCreation;
@property(strong,nullable) OCAppProviderAppName defaultAppName;
@property(weak,nullable) OCAppProviderApp *defaultApp;

@end

NS_ASSUME_NONNULL_END
