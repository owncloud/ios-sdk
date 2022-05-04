//
//  OCVFSTypes.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 02.05.22.
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
#import "OCLocation.h"
#import "OCTypes.h"

typedef NS_ENUM(NSInteger, OCVFSNodeType)
{
	OCVFSNodeTypeVirtualFolder, //!< Virtual folder node hosting child nodes
	OCVFSNodeTypeLocation, //!< Virtual node whose content is provided by a location
	OCVFSNodeTypeQuery //!< Virtual node whose content is provided by a query
};

//typedef id<NSObject> OCVFSOpaqueItem;
typedef NSString* OCVFSNodeID;
typedef NSString* OCVFSItemID NS_TYPED_EXTENSIBLE_ENUM;

NS_ASSUME_NONNULL_BEGIN

@protocol OCVFSItem <NSObject>

@end

extern OCVFSItemID OCVFSItemIDRoot;

NS_ASSUME_NONNULL_END
