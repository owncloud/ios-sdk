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

@interface OCResource : NSObject

@property(strong) OCResourceType type;
@property(strong) OCResourceIdentifier identifier;
@property(strong,nullable) OCResourceVersion version;
@property(strong,nullable) OCResourceStructureDescription structureDescription;

@property(assign) OCResourceStatus status;

@property(strong,nullable) OCResourceMetadata metaData;
@property(strong,nullable) NSData *data;

@end

NS_ASSUME_NONNULL_END
