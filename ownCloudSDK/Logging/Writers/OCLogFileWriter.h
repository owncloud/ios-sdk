//
//  OCLogFileWriter.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 31.10.18.
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

#import "OCLogWriter.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCLogFileWriter : OCLogWriter

@property(strong,class,nonatomic) NSURL *logFileURL;

@property(strong,readonly) NSURL *logFileURL;

- (instancetype)init;
- (instancetype)initWithLogFileURL:(NSURL *)url;

- (nullable NSError *)eraseOrTruncate;

@end

extern OCLogComponentIdentifier OCLogComponentIdentifierWriterFile;

NS_ASSUME_NONNULL_END
