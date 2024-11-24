//
//  OCSearchResult.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 31.10.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCDataSource.h"
#import "OCTypes.h"
#import "OCProgress.h"
#import "OCEvent.h"
#import "OCCore.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCSearchResult : NSObject

@property(weak,nullable) OCCore *core;

@property(strong) OCKQLQuery kqlQuery;
@property(strong) OCDataSource *results;

@property(strong,nullable) NSError *error;

@property(strong,nullable) OCProgress *progress;
- (void)cancel;

- (instancetype)initWithKQLQuery:(OCKQLQuery)kqlQuery core:(OCCore *)core;

// MARK: - Internals
- (void)_handleResultEvent:(OCEvent *)event;

@end

NS_ASSUME_NONNULL_END
