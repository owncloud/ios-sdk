//
//  NSURLSessionTaskMetrics+OCCompactSummary.m
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

#import "NSURLSessionTaskMetrics+OCCompactSummary.h"
#import <objc/runtime.h>

static NSString *sOCURLMetrics = @"sOCURLMetrics";

@implementation NSURLSessionTask (OCURLMetrics)

- (NSDate *)resumeTaskDate
{
	return (objc_getAssociatedObject(self, (__bridge void *)sOCURLMetrics));
}

- (void)setResumeTaskDate:(NSDate *)resumeTaskDate
{
	objc_setAssociatedObject(self, (__bridge void *)sOCURLMetrics, resumeTaskDate, OBJC_ASSOCIATION_RETAIN);
}

@end

@implementation NSURLSessionTaskMetrics (OCCompactSummary)

- (NSString *)compactSummaryWithTask:(NSURLSessionTask *)task
{
	NSMutableString *compactSummary = nil;
	NSDate *earliestDate = self.taskInterval.startDate;
	NSDate *resumeTaskDate = task.resumeTaskDate;

	compactSummary = [[NSMutableString alloc] initWithFormat:@"{ total: [%@ - %@, %0.02f sec], %@redirects: %lu, transactions: ", self.taskInterval.startDate, self.taskInterval.endDate, self.taskInterval.duration, ((resumeTaskDate!=nil) ? [NSString stringWithFormat:@"startedAfter: %0.02f, ", [resumeTaskDate timeIntervalSinceDate:earliestDate]] : @""), (unsigned long)self.redirectCount];

	void (^AppendMetric)(NSDate *date, NSString *label, NSDate *startDate) = ^(NSDate *date, NSString *label, NSDate *startDate) {
		if (date != nil)
		{
			if (startDate != nil)
			{
				[compactSummary appendFormat:@"%@: %0.02f (%0.02f)", label, [date timeIntervalSinceDate:earliestDate], [date timeIntervalSinceDate:startDate]];
			}
			else
			{
				[compactSummary appendFormat:@"%@: %0.02f", label, [date timeIntervalSinceDate:earliestDate]];
			}
		}
	};

	void (^AppendIntrvl)(NSDate *endDate, NSString *label, NSDate *startDate) = ^(NSDate *endDate, NSString *label, NSDate *startDate) {
		if (endDate != nil)
		{
			if (startDate != nil)
			{
				[compactSummary appendFormat:@", %@: %0.02f..%0.02f (%0.02f)", label, [startDate timeIntervalSinceDate:earliestDate], [endDate timeIntervalSinceDate:earliestDate], [endDate timeIntervalSinceDate:startDate]];
			}
			else
			{
				[compactSummary appendFormat:@", %@: %0.02f", label, [endDate timeIntervalSinceDate:earliestDate]];
			}
		}
	};

	[self.transactionMetrics enumerateObjectsUsingBlock:^(NSURLSessionTaskTransactionMetrics * _Nonnull transaction, NSUInteger idx, BOOL * _Nonnull stop) {
		[compactSummary appendFormat:@"%@[%lu: ", ((idx > 0) ? @", " : @""), (idx+1)];

		AppendMetric(transaction.fetchStartDate, 		@"fetchStart", 		nil);
		AppendIntrvl(transaction.domainLookupEndDate, 		@"DNS", 		transaction.domainLookupStartDate);
		AppendIntrvl(transaction.connectEndDate, 		@"connect",		transaction.connectStartDate);
		AppendIntrvl(transaction.secureConnectionEndDate, 	@"TLS", 		transaction.secureConnectionStartDate);
		AppendIntrvl(transaction.requestEndDate, 		@"request",		transaction.requestStartDate);
		AppendIntrvl(transaction.responseStartDate, 		@"cloud",		transaction.requestEndDate);
		AppendIntrvl(transaction.responseEndDate, 		@"response",		transaction.responseStartDate);

		[compactSummary appendString:@"]"];
	}];

	[compactSummary appendString:@" }"];

	return (compactSummary);
}

@end
