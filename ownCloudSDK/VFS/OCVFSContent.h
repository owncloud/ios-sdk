//
//  OCVFSContent.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.05.22.
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
#import "OCVFSNode.h"

@class OCCore;
@class OCQuery;

NS_ASSUME_NONNULL_BEGIN

@interface OCVFSContent : NSObject

@property(strong,nullable) OCBookmark *bookmark;
@property(weak,nullable) OCCore *core;

@property(strong,nullable) OCVFSNode *containerNode;

@property(strong,nullable) OCQuery *query;
@property(strong,nullable) NSArray<OCVFSNode *> *vfsChildNodes;

@property(assign) BOOL isSnapshot; //!< If YES, content is not self-refreshing and needs to be re-requested to get the latest version

@end

NS_ASSUME_NONNULL_END
