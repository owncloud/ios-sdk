//
//  OCLogFileRecord.h
//  ownCloudSDK
//
//  Created by Michael Neuwert on 16.05.2019.
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

@interface OCLogFileRecord : NSObject

@property(strong) NSString *name;
@property(strong, nullable) NSDate *creationDate;
@property(assign) int64_t size;

- (instancetype)initWithName:(NSString*)name creationDate:(NSDate*)date fileSize:(int64_t)size;

- (NSString*)fullPath;

@end

NS_ASSUME_NONNULL_END
