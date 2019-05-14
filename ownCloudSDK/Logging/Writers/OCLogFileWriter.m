//
//  OCLogFileWriter.m
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

#import "OCLogFileWriter.h"
#import "OCAppIdentity.h"
#import "OCMacros.h"

NSUInteger const OCDefaultMaxLogFileCount = 10;
NSTimeInterval const OCDefaultRotationTimeInterval = 60.0 * 60.0 * 24.0;

@interface OCLogFileWriter ()
{
	int _logFileFD;
	NSUInteger _maximumLogFileCount;

}
@end

static NSURL *sDefaultLogFileURL;

@implementation OCLogFileWriter

+ (void)setLogFileURL:(NSURL *)logFileURL
{
	sDefaultLogFileURL = logFileURL;
}

+ (NSURL *)logFileURL
{
	if (sDefaultLogFileURL == nil)
	{
		sDefaultLogFileURL = [[OCAppIdentity.sharedAppIdentity appGroupContainerURL] URLByAppendingPathComponent:@"ownCloudApp.log"];
	}

	return (sDefaultLogFileURL);
}

- (NSString *)name
{
	return (OCLocalized(@"Log file"));
}

- (instancetype)initWithLogFileURL:(NSURL *)url
{
	if ((self = [super initWithIdentifier:OCLogComponentIdentifierWriterFile]) != nil)
	{
		_logFileURL = url;
		_maximumLogFileCount = OCDefaultMaxLogFileCount;
		_rotationInterval = OCDefaultRotationTimeInterval;
	}

	return (self);
}

- (instancetype)init
{
	return ([self initWithLogFileURL:[self class].logFileURL]);
}

- (NSError *)open
{
	NSError *error = nil;

	if (!_isOpen)
	{
		// Open file
		if ((_logFileFD = open((const char *)_logFileURL.path.UTF8String, O_APPEND|O_WRONLY|O_CREAT, S_IRUSR|S_IWUSR)) != -1)
		{
			_isOpen = YES;

			OCLogDebug(@"Starting logging to %@", _logFileURL.path);
		}
		else
		{
			error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
		}
	}

	return (error);
}

- (NSError *)close
{
	NSError *error = nil;

	if (_isOpen)
	{
		[self appendMessage:[NSString stringWithFormat:@"-- %@: closing log file --", [NSDate date]]];

		if (close(_logFileFD) != 0)
		{
			error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
		}

		_logFileFD = 0;
		_isOpen = NO;
	}

	return (error);
}

- (void)appendMessage:(NSString *)message
{
	if (_isOpen)
	{
		NSData *messageData;

		if ((messageData = [message dataUsingEncoding:NSUTF8StringEncoding]) != nil)
		{
			write(_logFileFD, messageData.bytes, (size_t)messageData.length);
		}
	}
}

- (nullable NSError *)eraseOrTruncate:(NSURL*)url
{
	NSError *error = nil;

	if ([[NSFileManager defaultManager] fileExistsAtPath:url.path])
	{
		if (![[NSFileManager defaultManager] removeItemAtURL:url error:&error])
		{
			int truncateFD;

			if ((truncateFD = open((const char *)url.path.UTF8String, O_WRONLY|O_TRUNC, S_IRUSR|S_IWUSR)) != -1)
			{
				close(truncateFD);
			}
			else
			{
				error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
			}
		}
	}

	return (error);
}

- (nullable NSError *)eraseOrTruncate
{
	return [self eraseOrTruncate:self.logFileURL];
}

- (NSDate*)fileCreationDateForPath:(NSString*)path
{
	NSDate* creationDate = nil;

	if ([[NSFileManager defaultManager] fileExistsAtPath:self.logFileURL.path])
	{
		NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
		creationDate = attributes[NSFileCreationDate];
	}

	return creationDate;
}

- (NSString*)findFreeLogArchiveName
{
	NSInteger counter = 1;
	NSString *currentPath = self.logFileURL.path;
	NSString *newPath = nil;
	BOOL fileExists = NO;

	NSMutableArray *existingLogPaths = [NSMutableArray arrayWithCapacity:_maximumLogFileCount];
	
	do
	{
		newPath = [currentPath stringByAppendingPathExtension:[NSString stringWithFormat:@"%ld", counter]];
		fileExists = [[NSFileManager defaultManager] fileExistsAtPath:newPath];
		if (fileExists == YES)
		{
			[existingLogPaths addObject:newPath];
		}
	} while (fileExists || counter > _maximumLogFileCount);

	// If all possible file-names are occupied, we will find the oldest one and truncate / delete it
	if (fileExists)
	{
		[existingLogPaths sortUsingComparator:^NSComparisonResult(id  _Nonnull path1, id  _Nonnull path2) {
			NSDate *creationDate1 = [self fileCreationDateForPath:path1];
			NSDate *creationDate2 = [self fileCreationDateForPath:path2];
			if (creationDate1 != nil && creationDate2 != nil)
			{
				return [creationDate1 compare:creationDate2];
			}
			else
			{
				return NSOrderedSame;
			}
		}];

		// Set the file path to the one of the oldest log
		newPath = [existingLogPaths firstObject];

		// Erase or truncate old log
		[self eraseOrTruncate:[NSURL URLWithString:newPath]];
	}

	return newPath;
}

- (void)rotateIfRequired
{
	// Check the age of current log
	NSDate *logCreationDate = [self fileCreationDateForPath:self.logFileURL.path];
	if (logCreationDate != nil)
	{
		NSTimeInterval age = [logCreationDate timeIntervalSinceNow];
		if (age > self.rotationInterval)
		{
			NSString *arhivedLogPath = [self findFreeLogArchiveName];

			// TODO: Rename current log and start new one
		}
	}
}

@end

OCLogComponentIdentifier OCLogComponentIdentifierWriterFile = @"writer.file";
