//
//  OCCoreDirectoryUpdateJob.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.05.19.
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

NS_ASSUME_NONNULL_BEGIN

typedef NSNumber* OCCoreDirectoryUpdateJobID;

@interface OCCoreDirectoryUpdateJob : NSObject

@property(nullable,strong) OCCoreDirectoryUpdateJobID identifier;
@property(strong) OCPath path;

@property(nonatomic,strong) NSSet<OCCoreDirectoryUpdateJobID> *representedJobIDs; //!< The jobs represented by this job. Typically its own identifier and the identifiers of other jobs it was scheduled for.

@property(nonatomic,readonly) BOOL isForQuery;

+ (instancetype)withPath:(OCPath)path;

- (void)addRepresentedJobID:(nullable OCCoreDirectoryUpdateJobID)jobID;

@end

NS_ASSUME_NONNULL_END
