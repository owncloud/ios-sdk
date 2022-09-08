//
//  OCAppProviderApp.h
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
#import "OCAppProviderFileType.h"
#import "OCItem.h"
#import "OCResourceRequest.h"

@class OCAppProvider;

NS_ASSUME_NONNULL_BEGIN

@interface OCAppProviderApp : NSObject

@property(weak,nullable) OCAppProvider *provider;

@property(strong,nullable) OCAppProviderAppName name;
@property(strong,nullable) NSURL *iconURL;

@property(strong,nullable,nonatomic,readonly) OCResourceRequest *iconResourceRequest;
@property(strong,nullable,nonatomic,readonly) UIImage *icon;

@property(strong,nullable) NSArray<OCAppProviderFileType *> *supportedTypes;

- (void)addSupportedType:(OCAppProviderFileType *)type;

- (BOOL)supportsItem:(OCItem *)item;

@end

NS_ASSUME_NONNULL_END
