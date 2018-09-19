//
//  OCCore+CommandLocalModification.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 02.08.18.
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

#import "OCCore.h"
#import "OCCore+SyncEngine.h"
#import "OCCoreSyncContext.h"
#import "NSError+OCError.h"
#import "OCMacros.h"
#import "NSString+OCParentPath.h"
#import "OCLogger.h"

@implementation OCCore (CommandLocalModification)

#pragma mark - Command
- (NSProgress *)reportLocalModificationOfItem:(OCItem *)item withContentsOfFileAtURL:(NSURL *)localFileURL options:(NSDictionary *)options placeholderCompletionHandler:(OCCoreActionResultHandler)placeholderCompletionHandler resultHandler:(OCCoreUploadResultHandler)completionHandler
{
	return (nil);
}

@end
