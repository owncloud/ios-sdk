//
//  NSURLSessionTaskMetrics+OCCompactSummary.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 01.04.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURLSessionTask (OCURLMetrics)

@property(strong,nullable,nonatomic) NSDate *resumeTaskDate;

@end

@interface NSURLSessionTaskMetrics (OCCompactSummary)

- (NSString *)compactSummaryWithTask:(NSURLSessionTask *)task;

@end

NS_ASSUME_NONNULL_END
