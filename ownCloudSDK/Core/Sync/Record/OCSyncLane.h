//
//  OCSyncLane.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 29.04.19.
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
#import "OCTypes.h"
#import "OCLogger.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCSyncLane : NSObject <NSSecureCoding, OCLogPrivacyMasking>

@property(nullable,strong) OCSyncLaneID identifier;	//!< The database ID of the sync lane, uniquely identifying the lane
@property(nullable,strong) NSSet <OCSyncLaneID> *afterLanes; //!< The sync lanes this lane waits to complete before starting
@property(nullable,strong) NSSet <OCSyncLaneTag> *tags;	//!< The lane tags covered by sync lane

#pragma mark - Tag interface
- (BOOL)coversTags:(nullable NSSet <OCSyncLaneTag> *)tags prefixMatches:(nullable NSUInteger *)outPrefixMatches identicalTags:(nullable NSUInteger *)outIdenticalMatches; //!< Returns YES if the set includes any tags covered by the tags of the lane. Returns kind of matches via passed in integer pointers.
- (void)extendWithTags:(nullable NSSet <OCSyncLaneTag> *)tags;	//!< Extends the lane's tags with the passed tags

@end

NS_ASSUME_NONNULL_END
