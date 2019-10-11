//
//  NSString+OCPath.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 17.06.18.
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

#import <Foundation/Foundation.h>
#import "OCTypes.h"
#import "OCItem.h"

@interface NSString (OCPath)

@property(readonly,strong,nonatomic) OCPath parentPath;
@property(readonly,nonatomic) BOOL isRootPath;

@property(readonly,strong,nonatomic) OCPath normalizedDirectoryPath;
@property(readonly,strong,nonatomic) OCPath normalizedFilePath;

@property(readonly,nonatomic) OCItemType itemTypeByPath;
- (OCPath)normalizedPathForItemType:(OCItemType)itemType;

- (OCPath)pathForSubdirectoryWithName:(NSString *)subDirectoryName;

@property(readonly,nonatomic) BOOL isUnnormalizedPath;
@property(readonly,nonatomic) BOOL isNormalizedDirectoryPath;

@end
