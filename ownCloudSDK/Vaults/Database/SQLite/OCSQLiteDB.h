//
//  OCSQLiteDB.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 14.03.18.
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

#import <sqlite3.h>

@interface OCSQLiteDB : NSObject

@property(strong) NSURL *fileURL;

- (instancetype)initWithURL:(NSURL *)sqliteFileURL;

@end
