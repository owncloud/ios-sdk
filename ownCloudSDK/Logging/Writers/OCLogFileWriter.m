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

OCIPCNotificationName OCLogFileWriterLogRecordsChangedRemoteNotification = @"org.owncloud.log_records_remote_change";

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
		NSString *logFileName = [[[OCAppIdentity sharedAppIdentity] appGroupIdentifier] stringByReplacingOccurrencesOfString:@"group." withString:@""];
		sDefaultLogFileURL = [[OCAppIdentity.sharedAppIdentity appGroupLogsContainerURL] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.log", logFileName]];
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

		[OCIPNotificationCenter.sharedNotificationCenter addObserver:self forName:OCLogFileWriterLogRecordsChangedRemoteNotification withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, id  _Nonnull observer, OCIPCNotificationName  _Nonnull notificationName) {
			[[NSNotificationCenter defaultCenter] postNotificationName:OCLogFileWriterLogRecordsChangedNotification object:nil];
		}];
	}

	return (self);
}

- (instancetype)init
{
	return ([self initWithLogFileURL:[self class].logFileURL]);
}

- (void)dealloc
{
	[OCIPNotificationCenter.sharedNotificationCenter removeObserver:self forName:OCLogFileWriterLogRecordsChangedRemoteNotification];
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

			// Write the LogIntro synchronously to ensure these lines are written
			// at the start of the logfile and can't get rerouted due to log rotation
			OCPFSLog(nil, (@[@"LogIntro"]), @"Starting logging to %@", _logFileURL.path);
			OCPFSLog(nil, (@[@"LogIntro"]), @"%@", OCLogger.sharedLogger.logIntro);

			_logFileVnodeSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, _logFileFD, DISPATCH_VNODE_RENAME|DISPATCH_VNODE_DELETE, OCLogger.sharedLogger.writeQueue);

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

				if (OCLoggingEnabled())
				{
					if ((error = [self open]) != nil)
					{
						NSLog(@"Error re-opening writer %@: %@", self, error);
					}
				}
			});

			dispatch_resume(_logFileVnodeSource);

			[self _scheduleLogRotationTimer];
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
		if (OCLogger.logFormat == OCLogFormatText)
		{
			[self appendMessageData:[[NSString stringWithFormat:@"-- %@: closing log file --", [NSDate date]] dataUsingEncoding:NSUTF8StringEncoding]];
		}

		if (close(_logFileFD) != 0)
		{
			error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
		}

		_logFileFD = 0;
		_isOpen = NO;

		[self _unscheduleLogRotationTimer];
	}

	return (error);
}

- (void)appendMessageData:(NSData *)data
{
	if (_isOpen && (data != nil))
	{
		write(_logFileFD, data.bytes, (size_t)data.length);
	}
}

- (NSArray<OCLogFileRecord*>*)logRecords
{
	NSError *error = nil;

	// Get contents of log directory
	NSArray *urls = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:OCAppIdentity.sharedAppIdentity.appGroupLogsContainerURL
						      includingPropertiesForKeys:@[NSURLCreationDateKey, NSURLFileSizeKey]
									 options:0
									   error:&error];

	NSMutableArray<OCLogFileRecord*> *records = [NSMutableArray new];

	// Create an array of log records
	for (NSURL* url in urls)
	{
		OCLogFileRecord *record = [[OCLogFileRecord alloc] initWithURL:url];
		[records addObject:record];
	}

	// Sort by creation date
	[records sortUsingComparator:^NSComparisonResult(OCLogFileRecord* _Nonnull record1, OCLogFileRecord* _Nonnull record2) {

		if (record1.creationDate != nil && record2.creationDate != nil)
		{
			return [record1.creationDate compare:record2.creationDate];
		}
		else
		{
			return NSOrderedSame;
		}
	}];

	return records;
}

- (void)deleteLogRecord:(OCLogFileRecord*)record
{
	if (record)
	{
		[self _eraseOrTruncate:record.url];
	}
}

- (void)cleanUpLogs:(BOOL)removeAll
{
	NSMutableArray<OCLogFileRecord*> *logRecords = [NSMutableArray arrayWithArray:[self logRecords]];

	NSUInteger maxFileCountToKeep = removeAll ? 0 : _maximumLogFileCount;

	BOOL deletionRequired = [logRecords count] > maxFileCountToKeep;
	if (deletionRequired)
	{
		// Remove old files which are exceeding maximum allowed file count
		while ([logRecords count] > maxFileCountToKeep) {
			OCLogFileRecord *firstRecord = [logRecords firstObject];
			[self deleteLogRecord:firstRecord];
			[logRecords removeObjectAtIndex:0];
		}

		[self _notifyAboutChangesInLogStorage];
	}
}

- (void)rotate
{
	NSError *error = nil;

	// Construct path for the archived log
	NSString *timeStamp = [OCLogWriter timestampStringFrom:[NSDate date]];
	NSString *transformedTimestamp = [timeStamp stringByReplacingOccurrencesOfString:@"[ /:]+" withString:@"_" options:NSRegularExpressionSearch range:NSMakeRange(0, [timeStamp length])];

	NSString *archivedLogPath = [self.logFileURL.path stringByAppendingFormat:@".%@", transformedTimestamp];

	// Rename current log and start new one
	[[NSFileManager defaultManager] moveItemAtPath:self.logFileURL.path toPath:archivedLogPath error:&error];

	// Notify about addition of a new file
	[self _notifyAboutChangesInLogStorage];

	// Check if some old logs can be deleted
	[self cleanUpLogs:NO];
}

#pragma mark - Private methods

- (void)_notifyAboutChangesInLogStorage
{
	// Notify observers that contents of the log storage have changed
	[OCIPNotificationCenter.sharedNotificationCenter postNotificationForName:OCLogFileWriterLogRecordsChangedRemoteNotification ignoreSelf:YES];
	[[NSNotificationCenter defaultCenter] postNotificationName:OCLogFileWriterLogRecordsChangedNotification object:nil];
}

- (nullable NSError *)_eraseOrTruncate:(NSURL*)url
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

- (NSDictionary*)_attributesForPath:(NSString*)path
{
	NSDictionary *attributes = nil;

	if ([[NSFileManager defaultManager] fileExistsAtPath:path])
	{
		attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
	}

	return attributes;
}

- (void)_scheduleLogRotationTimer
{
	[self _unscheduleLogRotationTimer];
	_logRotationTimerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, OCLogger.sharedLogger.writeQueue);

	__weak __auto_type weakSelf = self;
	dispatch_source_set_event_handler(_logRotationTimerSource, ^{
		[weakSelf _rotateLogIfRequired];
	});

	dispatch_time_t fireTime = dispatch_time(DISPATCH_TIME_NOW, OCDefaultLogRotationFrequency);

	dispatch_source_set_timer(_logRotationTimerSource, fireTime, DISPATCH_TIME_FOREVER, 1ull * NSEC_PER_SEC);
	dispatch_resume(_logRotationTimerSource);
}

- (void)_unscheduleLogRotationTimer
{
	if (_logRotationTimerSource) {
		dispatch_source_cancel(_logRotationTimerSource);
		_logRotationTimerSource = NULL;
	}
}

- (void)_rotateLogIfRequired
{
	NSDate *logCreationDate = [self _attributesForPath:self.logFileURL.path][NSFileCreationDate];

	if (logCreationDate != nil)
	{
		// Check the age of current log
		NSTimeInterval age = [logCreationDate timeIntervalSinceNow];
		if (-age > self.rotationInterval)
		{
			[self rotate];
		}
		else
		{
			[self _scheduleLogRotationTimer];
		}
	}
}

@end

NSNotificationName OCLogFileWriterLogRecordsChangedNotification = @"OCLogFileWriterLogRecordsChangedNotification";
OCLogComponentIdentifier OCLogComponentIdentifierWriterFile = @"writer.file";
