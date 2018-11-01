//
//  OCLogFileSource.m
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

#import "OCLogFileSource.h"

@implementation OCLogFileSource

#pragma mark - Init & Dealloc
- (instancetype)initWithFILE:(FILE *)originalFile name:(NSString *)name logger:(OCLogger *)logger
{
	if ((self = [super initWithName:name logger:logger]) != nil)
	{
		_originalFile = originalFile;
	}

	return (self);
}

- (void)dealloc
{
	[self stop];
}

#pragma mark - Start redirection
- (void)start
{
	if (_pipe == nil)
	{
		if ((_pipe = [NSPipe pipe]) != nil)
		{
			NSFileHandle *readingFileHandle = _pipe.fileHandleForReading;
			NSFileHandle *writingFileHandle = _pipe.fileHandleForWriting;

			// Save originalFile FD by duplication
			fflush(_originalFile);
			fgetpos(_originalFile, &_clonedOriginalFileFilePos);
			_clonedOriginalFileFD = dup(fileno(_originalFile));

			// Replace originalFile FD with writingFileHandle's
			dup2(writingFileHandle.fileDescriptor, fileno(_originalFile));

			// Listen for new data on a dispatch source
			if ((_dispatchSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, readingFileHandle.fileDescriptor, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0))) != NULL)
			{
				__weak OCLogger *logger = self.logger;
				NSString *name = self.name;

				NSString *nsLogFragment = [NSString stringWithFormat:@" %@[%d:", NSProcessInfo.processInfo.processName, getpid()];

				dispatch_source_set_event_handler(_dispatchSource, ^{
					@autoreleasepool {
						NSData *availableData;

						if ((availableData = [readingFileHandle availableData]) != nil)
						{
							NSString *logMessage;

							if ((logMessage = [[NSString alloc] initWithData:availableData encoding:NSUTF8StringEncoding]) != nil)
							{
								NSRange nsLogFragmentRange = [logMessage rangeOfString:nsLogFragment];
								uint64_t threadID = 0;
								NSDate *timestamp = [NSDate date];
								NSString *sourceName = name;

								if (nsLogFragmentRange.location != NSNotFound)
								{
									// NSLog fragment found
									NSUInteger fragmentEndRangeLocation = nsLogFragmentRange.location + nsLogFragmentRange.length;
									NSRange closingBracketRange = [logMessage rangeOfString:@"] " options:0 range:NSMakeRange(fragmentEndRangeLocation, logMessage.length - fragmentEndRangeLocation)];

									if (closingBracketRange.location != NSNotFound)
									{
										threadID = [[logMessage substringWithRange:NSMakeRange(fragmentEndRangeLocation, closingBracketRange.location-fragmentEndRangeLocation)] integerValue];
										logMessage = [logMessage substringWithRange:NSMakeRange(closingBracketRange.location+closingBracketRange.length, logMessage.length - (closingBracketRange.location+closingBracketRange.length)-1)];
										sourceName = @"NSLog";
									}
								}

								[logger rawAppendLogLevel:OCLogLevelDefault functionName:nil file:sourceName line:0 logMessage:logMessage threadID:threadID timestamp:timestamp];
							}
						}
					}
				});

				dispatch_resume(_dispatchSource);
			}
		}
	}
}

- (void)stop
{
	if (_pipe != nil)
	{
		dup2(_clonedOriginalFileFD, fileno(_originalFile));
		close(_clonedOriginalFileFD);

		clearerr(_originalFile);
		fsetpos(_originalFile, &_clonedOriginalFileFilePos);

		dispatch_source_cancel(_dispatchSource);
		_dispatchSource = NULL;

		_pipe = nil;
	}
}

- (nullable NSError *)writeDataToOriginalFile:(NSData *)data
{
	if (data != nil)
	{
		if (_pipe != nil)
		{
			write(_clonedOriginalFileFD, data.bytes, data.length);
		}
		else
		{
			fwrite(data.bytes, data.length, 1, _originalFile);
		}
	}

	return (nil);
}

@end
