//
//  OCBookmark+Prepopulation.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 30.06.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
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

#import "OCBookmark+Prepopulation.h"
#import "OCVault+Prepopulation.h"
#import "NSProgress+OCExtensions.h"
#import "NSError+OCError.h"
#import "OCLogger.h"
#import "OCMacros.h"

@implementation OCBookmark (Prepopulation)

- (NSProgress *)prepopulateWithCompletionHandler:(void(^)(NSError *error))completionHandler
{
	NSProgress *rootProgress = NSProgress.indeterminateProgress;
	OCVault *vault = [[OCVault alloc] initWithBookmark:self];

	rootProgress.localizedDescription = OCLocalized(@"Opening vault…");

	[vault openWithCompletionHandler:^(id sender, NSError *error) {
		if (error != nil)
		{
			// Error opening vault
			completionHandler(error);
		}
		else if (rootProgress.cancelled)
		{
			// Cancelled: close and return
			[vault closeWithCompletionHandler:^(id sender, NSError *error) {
				completionHandler(OCError(OCErrorCancelled));
			}];
		}
		else
		{
			// Retrieve infinite PROPFIND
			NSProgress *retrieveProgress;
			NSTimeInterval startTime = NSDate.timeIntervalSinceReferenceDate;

			OCTLog(@[@"Prepop"], @"Starting to retrieve and prepopulate database with items…");

			rootProgress.localizedDescription = OCLocalized(@"Retrieving metadata…");

			if ((retrieveProgress = [vault retrieveMetadataWithCompletionHandler:^(NSError * _Nullable retrieveError, OCDAVRawResponse * _Nullable davRawResponse) {
				if (rootProgress.cancelled || (retrieveError != nil))
				{
					// Cancelled or encountered error: close and return
					[vault closeWithCompletionHandler:^(id sender, NSError *error) {
						[vault eraseDavRawResponses];

						completionHandler((retrieveError != nil) ? retrieveError : OCError(OCErrorCancelled));
					}];
				}
				else
				{
					// Populate database
					NSProgress *populateProgress;
					NSTimeInterval prepopulateStartTime = NSDate.timeIntervalSinceReferenceDate;

					OCLogDebug (@"Error=%@, rawResponse.url=%@", retrieveError, davRawResponse.responseDataURL);

					rootProgress.localizedDescription = OCLocalized(@"Populating database…");

					OCTLog(@[@"Prepop"], @"Retrieved item metadata in %.0f sec", NSDate.timeIntervalSinceReferenceDate - startTime);

					if ((populateProgress = [vault prepopulateDatabaseWithRawResponse:davRawResponse progressHandler:^(NSUInteger folderCount, NSUInteger fileCount) {
						rootProgress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"%lu files in %lu folders"), (unsigned long)fileCount, folderCount];
					} completionHandler:^(NSError * _Nullable parseError) {
						// Close and return
						rootProgress.localizedDescription = OCLocalized(@"Closing vault…");

						[vault closeWithCompletionHandler:^(id sender, NSError *error) {
							[vault eraseDavRawResponses];

							NSTimeInterval completeTime = NSDate.timeIntervalSinceReferenceDate - startTime;
							NSTimeInterval parseTime = NSDate.timeIntervalSinceReferenceDate - prepopulateStartTime;

							OCTLog(@[@"Prepop"], @"Completed prepolution in %.0f sec (retrieval: %.0f sec, parsing: %.0f sec)", completeTime, (completeTime-parseTime), parseTime);

							completionHandler((parseError != nil) ? parseError : (rootProgress.cancelled ? OCError(OCErrorCancelled) : nil));
						}];
					}]) != nil)
					{
						[rootProgress addChild:populateProgress withPendingUnitCount:50];
					}
				}
			}]) != nil)
			{
				[rootProgress addChild:retrieveProgress withPendingUnitCount:50];
			}
		}
	}];

	return (rootProgress);
}

- (NSProgress *)prepopulateWithStreamCompletionHandler:(void(^)(NSError *error))completionHandler
{
	NSProgress *rootProgress = NSProgress.indeterminateProgress;
	OCVault *vault = [[OCVault alloc] initWithBookmark:self];

	rootProgress.localizedDescription = OCLocalized(@"Opening vault…");

	[vault openWithCompletionHandler:^(id sender, NSError *error) {
		if (error != nil)
		{
			// Error opening vault
			completionHandler(error);
		}
		else if (rootProgress.cancelled)
		{
			// Cancelled: close and return
			[vault closeWithCompletionHandler:^(id sender, NSError *error) {
				completionHandler(OCError(OCErrorCancelled));
			}];
		}
		else
		{
			// Retrieve infinite PROPFIND
			NSProgress *retrieveProgress;
			NSTimeInterval startTime = NSDate.timeIntervalSinceReferenceDate;

			OCTLog(@[@"Prepop"], @"Starting to retrieve and prepopulate database with items…");

			rootProgress.localizedDescription = OCLocalized(@"Retrieving metadata…");

			if ((retrieveProgress = [vault streamMetadataWithCompletionHandler:^(NSError * _Nullable retrieveError, NSInputStream * _Nullable inputStream, NSString * _Nullable basePath) {
				if (rootProgress.cancelled || (retrieveError != nil))
				{
					// Cancelled or encountered error: close and return
					[vault closeWithCompletionHandler:^(id sender, NSError *error) {
						completionHandler((retrieveError != nil) ? retrieveError : OCError(OCErrorCancelled));
					}];
				}
				else
				{
					// Populate database
					NSProgress *populateProgress;

					OCLogDebug (@"Error=%@, inputStream=%@, basePath=%@", retrieveError, inputStream, basePath);

					rootProgress.localizedDescription = OCLocalized(@"Populating database…");

					OCTLog(@[@"Prepop"], @"Retrieved item metadata in %.0f sec", NSDate.timeIntervalSinceReferenceDate - startTime);

					if ((populateProgress = [vault prepopulateDatabaseWithInputStream:inputStream basePath:basePath progressHandler:^(NSUInteger folderCount, NSUInteger fileCount) {
						rootProgress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"%lu files in %lu folders"), (unsigned long)fileCount, folderCount];
					} completionHandler:^(NSError * _Nullable parseError) {
						// Close and return
						rootProgress.localizedDescription = OCLocalized(@"Closing vault…");

						[vault closeWithCompletionHandler:^(id sender, NSError *error) {
							NSTimeInterval completeTime = NSDate.timeIntervalSinceReferenceDate - startTime;

							OCTLog(@[@"Prepop"], @"Completed prepolution in %.0f sec (retrieval + parsing)", completeTime);

							completionHandler((parseError != nil) ? parseError : (rootProgress.cancelled ? OCError(OCErrorCancelled) : nil));
						}];
					}]) != nil)
					{
						[rootProgress addChild:populateProgress withPendingUnitCount:50];
					}
				}
			}]) != nil)
			{
				[rootProgress addChild:retrieveProgress withPendingUnitCount:50];
			}
		}
	}];

	return (rootProgress);
}

@end
