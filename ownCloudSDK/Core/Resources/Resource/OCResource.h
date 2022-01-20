//
//  OCResource.h
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
#import <CoreGraphics/CoreGraphics.h>

#import "OCResourceTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class OCResourceRequest;

@interface OCResource : NSObject <NSSecureCoding>

@property(strong) OCResourceType type;
@property(strong) OCResourceIdentifier identifier;
@property(strong,nullable) OCResourceVersion version;
@property(strong,nullable) OCResourceStructureDescription structureDescription;

@property(strong,nullable) OCResourceSourceIdentifier originSourceIdentifier; //!< Identifier of the source the resource originated from (optional, NOT serialized)

@property(assign) OCResourceQuality quality;

@property(strong,nullable) OCResourceMetadata metaData;
@property(strong,nullable) OCResourceMIMEType mimeType;

@property(strong,nullable) NSURL *url; //!< URL at which the resource is stored (optional)
@property(strong,nullable,nonatomic) NSData *data; //!< Data of the resource. If data == nil and url != nil, loads contents of url.

@property(strong,nullable) NSDate *timestamp;

- (instancetype)initWithRequest:(OCResourceRequest *)request;

@end

extern OCResourceType OCResourceTypeAny;
extern OCResourceType OCResourceTypeAvatar;
extern OCResourceType OCResourceTypeItemThumbnail;

NS_ASSUME_NONNULL_END
