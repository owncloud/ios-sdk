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
int64_t const OCDefaultLogRotationFrequency = 60 * NSEC_PER_SEC;

@interface OCLogFileWriter ()
{
	int _logFileFD;
	dispatch_source_t _logFileVnodeSource;
	dispatch_source_t _logRotationTimerSource;

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

			_logFileVnodeSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, _logFileFD, DISPATCH_VNODE_RENAME, [OCLogWriter queue]);

			dispatch_source_set_event_handler(_logFileVnodeSource, ^{
				// Close and re-open current file
				NSError *error = nil;

				if(fsync(self->_logFileFD) != 0)
				{
					error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
					NSLog(@"Error syncing log file %@: %@", self, error);
				}

				if ((error = [self close]) != nil)
				{
					NSLog(@"Error closing writer on re-name %@: %@", self, error);
				}

				if (self->_logFileVnodeSource)
				{
					dispatch_source_cancel(self->_logFileVnodeSource);
					self->_logFileVnodeSource = nil;
				}

				if ((error = [self open]) != nil)
				{
					NSLog(@"Error re-opening writer %@: %@", self, error);
				}
			});

			dispatch_resume(_logFileVnodeSource);

			[self scheduleLogRotationTimer];
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

		[self unscheduleLogRotationTimer];
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

- (nullable NSError *)eraseOrTruncate:(NSString*)path
{
	NSError *error = nil;

	if ([[NSFileManager defaultManager] fileExistsAtPath:path])
	{

		if (![[NSFileManager defaultManager] removeItemAtPath:path error:&error])
		{
			int truncateFD;

			if ((truncateFD = open((const char *)path.UTF8String, O_WRONLY|O_TRUNC, S_IRUSR|S_IWUSR)) != -1)
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
	return [self eraseOrTruncate:self.logFileURL.path];
}

- (NSDate*)fileCreationDateForPath:(NSString*)path
{
	NSDate* creationDate = nil;

	if ([[NSFileManager defaultManager] fileExistsAtPath:path])
	{
		NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
		creationDate = attributes[NSFileCreationDate];
	}

	return creationDate;
}

- (void)scheduleLogRotationTimer
{
	[self unscheduleLogRotationTimer];
	_logRotationTimerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, [OCLogWriter queue]);

	__weak __auto_type weakSelf = self;
	dispatch_source_set_event_handler(_logRotationTimerSource, ^{
		[weakSelf rotateLogIfRequired];
	});

	dispatch_time_t fireTime = dispatch_time(DISPATCH_TIME_NOW, OCDefaultLogRotationFrequency);

	dispatch_source_set_timer(_logRotationTimerSource, fireTime, DISPATCH_TIME_FOREVER, 1ull * NSEC_PER_SEC);
	dispatch_resume(_logRotationTimerSource);
}

- (void)unscheduleLogRotationTimer
{
	if (_logRotationTimerSource) {
		dispatch_source_cancel(_logRotationTimerSource);
		_logRotationTimerSource = NULL;
	}
}

- (NSArray*)logFiles
{
	NSError *error = nil;

	// Get contents of directory
	NSString *directoryPath = [[OCAppIdentity.sharedAppIdentity appGroupContainerURL] path];
	NSArray *directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directoryPath
																					 error:&error];

	if (error == nil)
	{
		// Filter log files
		NSString *logNamePattern = @"*.log.*";
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF like[cd] %@", logNamePattern];
		return [directoryContents filteredArrayUsingPredicate:predicate];
	}
	else
	{
		return nil;
	}
}

- (void)cleanUpLogs:(BOOL)removeAll
{
	NSString *directoryPath = [[OCAppIdentity.sharedAppIdentity appGroupContainerURL] path];
	NSArray *logFiles = [self logFiles];

	if (logFiles != nil)
	{
		NSMutableArray *existingLogPaths = [NSMutableArray arrayWithArray:logFiles];

		// Sort by creation date
		[existingLogPaths sortUsingComparator:^NSComparisonResult(id  _Nonnull file1, id  _Nonnull file2) {

			NSString *path1 = [directoryPath stringByAppendingPathComponent:file1];
			NSString *path2 = [directoryPath stringByAppendingPathComponent:file2];

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

		NSUInteger maxFileCountToKeep = removeAll ? 0 : _maximumLogFileCount;

		// Remove old files which are exceeding maximum allowed file count
		while ([existingLogPaths count] > maxFileCountToKeep) {
			NSString *pathToDelete = [directoryPath stringByAppendingPathComponent:[existingLogPaths firstObject]];

			[self eraseOrTruncate:pathToDelete];
			[existingLogPaths removeObjectAtIndex:0];
		}
	}
}

- (void)rotateLogIfRequired
{
	NSError *error = nil;
	NSDate *logCreationDate = [self fileCreationDateForPath:self.logFileURL.path];

	if (logCreationDate != nil)
	{
		// Check the age of current log
		NSTimeInterval age = [logCreationDate timeIntervalSinceNow];
		if (-age > self.rotationInterval)
		{
			// Construct path for the archived log
			NSString *timeStamp = [OCLogWriter timestampStringFrom:[NSDate date]];
			NSString *transformedTimestamp = [timeStamp stringByReplacingOccurrencesOfString:@"[ /:]+" withString:@"_" options:NSRegularExpressionSearch range:NSMakeRange(0, [timeStamp length])];

			NSString *arhivedLogPath = [self.logFileURL.path stringByAppendingFormat:@".%@", transformedTimestamp];

			// Rename current log and start new one
			[[NSFileManager defaultManager] moveItemAtPath:self.logFileURL.path toPath:arhivedLogPath error:&error];

			// Check if some old logs can be deleted
			[self cleanUpLogs:NO];
		}
		else
		{
			[self scheduleLogRotationTimer];
		}
	}
}

@end

OCLogComponentIdentifier OCLogComponentIdentifierWriterFile = @"writer.file";
