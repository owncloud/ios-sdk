//
//  OCSyncAction+FileProvider.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 17.11.18.
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

#import "OCSyncAction+FileProvider.h"
#import "OCHTTPPipelineTask.h"
#import "NSURLSessionTaskMetrics+OCCompactSummary.h"
#import "OCVault+Internal.h"

@implementation OCSyncAction (FileProviderProgressReporting)

- (void)setupProgressSupportForItem:(OCItem *)item options:(NSDictionary **)options syncContext:(OCSyncContext * _Nonnull)syncContext
{
	if (self.core.postFileProviderNotifications && (item.fileID != nil) && (self.core.vault.fileProviderDomain!=nil))
	{
		/*
		 Check if a placeholder/file already exists here before registering this URL session for the item. Otherwise, the SDK may find itself on
		 the receiving end of this error:

		 [default] [ERROR] Failed registering URL session task <__NSCFBackgroundDownloadTask: 0x7f81efa08010>{ taskIdentifier: 1041 } with item 00000042oc9qntjidejl; Error Domain=com.apple.FileProvider Code=-1005 "The file doesn’t exist." UserInfo={NSFileProviderErrorNonExistentItemIdentifier=00000042oc9qntjidejl}

		 Error registering <__NSCFBackgroundDownloadTask: 0x7f81efa08010>{ taskIdentifier: 1041 } for 00000042oc9qntjidejl: Error Domain=com.apple.FileProvider Code=-1005 "The file doesn’t exist." UserInfo={NSFileProviderErrorNonExistentItemIdentifier=00000042oc9qntjidejl} [OCCoreSyncActionDownload.m:71|FULL]
		 */
		NSURL *localURL, *placeholderURL;

		if (((localURL = [self.core localURLForItem:item]) != nil) &&
		    ((placeholderURL = [NSFileProviderManager placeholderURLForURL:localURL]) != nil))
		{
			if ([[NSFileManager defaultManager] fileExistsAtPath:placeholderURL.path])
			{
				NSFileProviderDomain *fileProviderDomain = self.core.vault.fileProviderDomain;

				OCLogDebug(@"record %@ will register URLTask for %@", syncContext.syncRecord, item);

				OCHTTPRequestObserver observer = [^(OCHTTPPipelineTask *task, OCHTTPRequest *request, OCHTTPRequestObserverEvent event) {
					if ((event == OCHTTPRequestObserverEventTaskResume) && (task.urlSessionTask != nil))
					{
						OCLogDebug(@"record %@ is registering URLTask for %@", syncContext.syncRecord, item);

						[[NSFileProviderManager managerForDomain:fileProviderDomain] registerURLSessionTask:task.urlSessionTask forItemWithIdentifier:item.localID completionHandler:^(NSError * _Nullable error) {
							OCLogDebug(@"record %@ returned from registering URLTask %@ for %@ with error=%@", syncContext.syncRecord, task.urlSessionTask, item, error);

							if (error != nil)
							{
								OCLogError(@"error registering %@ for %@: %@", task.urlSessionTask, item.localID, error);
							}

							// File provider detail: the task may not be started until after this completionHandler was called
							task.urlSessionTask.resumeTaskDate = [NSDate new];
							[task.urlSessionTask resume];
						}];

						return (YES);
					}

					return (NO);
				} copy];

				if (*options == nil)
				{
					*options = @{ OCConnectionOptionRequestObserverKey : observer };
				}
				else
				{
					NSMutableDictionary *mutableOptions = [*options mutableCopy];

					mutableOptions[OCConnectionOptionRequestObserverKey] = observer;

					*options = mutableOptions;
				}
			}
		}
	}
}

@end

