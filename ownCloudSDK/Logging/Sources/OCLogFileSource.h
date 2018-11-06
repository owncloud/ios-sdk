//
//  OCLogFileSource.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 01.11.18.
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

#import "OCLogSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCLogFileSource : OCLogSource
{
	FILE *_originalFile;

	int _clonedOriginalFileFD;
	fpos_t _clonedOriginalFileFilePos;

	NSPipe *_pipe;
	dispatch_source_t _dispatchSource;
}

@property(readonly) int clonedOriginalFileFD;

- (instancetype)initWithFILE:(FILE *)originalFile name:(NSString *)name logger:(OCLogger *)logger;

- (nullable NSError *)writeDataToOriginalFile:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
