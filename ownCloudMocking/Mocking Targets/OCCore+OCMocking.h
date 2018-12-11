//
//  OCCore+OCMocking.h
//  ownCloudMocking
//
//  Created by Javier Gonzalez on 04/12/2018.
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

#import <ownCloudSDK/ownCloudSDK.h>
#import "OCMockManager.h"

@interface OCCore (OCMocking)

- (NSProgress *)ocm_createFolder:(NSString *)folderName inside:(OCItem *)parentItem options:(NSDictionary<OCCoreOption,id> *)options resultHandler:(OCCoreActionResultHandler)resultHandler;

@end

typedef NSProgress *(^OCMockOCCoreCreateFolderBlock)(NSString *folderName, OCItem *parentItem,  NSDictionary<OCCoreOption,id> *, OCCoreActionResultHandler);
extern OCMockLocation OCMockLocationOCCoreCreateFolder;
