//
//  OCSyncActionCopyMove.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.09.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2018, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCSyncAction.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCSyncActionCopyMove : OCSyncAction

@property(strong) NSString *targetName;
@property(strong) OCItem *targetParentItem;

@property(strong) OCItem *processingItem;

@property(assign) BOOL isRename;
@property(nullable,strong) NSArray <OCLocalID> *associatedItemLocalIDs;
@property(nullable,strong) NSSet <OCSyncLaneTag> *associatedItemLaneTags;

- (instancetype)initWithItem:(OCItem *)item action:(OCSyncActionIdentifier)actionIdentifier targetName:(NSString *)targetName targetParentItem:(OCItem *)targetParentItem isRename:(BOOL)isRename;

@end

NS_ASSUME_NONNULL_END
