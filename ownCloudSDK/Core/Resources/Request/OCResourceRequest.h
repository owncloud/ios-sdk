//
//  OCResourceRequest.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 30.09.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
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

#import <Foundation/Foundation.h>
#import "OCResourceTypes.h"
#import "OCItem.h"
#import "OCUser.h"

NS_ASSUME_NONNULL_BEGIN

@class OCResourceRequest;
@class OCResource;

typedef void(^OCResourceRequestChangeHandler)(OCResourceRequest *request, BOOL updatedResourceContent);

@interface OCResourceRequest : NSObject

@property(weak,nullable) OCCore *core;

@property(strong,readonly) OCResourceType type;
@property(strong) OCResourceIdentifier identifier;

@property(strong,nullable) OCResourceVersion version;
@property(strong,nullable) OCResourceStructureDescription structureDescription;

@property(assign) CGSize maximumSizeInPoints;
@property(assign) CGFloat scale;

@property(assign) BOOL waitForConnectivity;

@property(strong,nullable) OCResource *resource;

- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
