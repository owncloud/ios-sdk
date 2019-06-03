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

@property(readonly) NSURL *url;
@property(readonly) NSString *name;
@property(readonly, nullable) NSDate *creationDate;
@property(readonly) int64_t size;

- (instancetype)initWithURL:(NSURL*)url;

@end

NS_ASSUME_NONNULL_END
