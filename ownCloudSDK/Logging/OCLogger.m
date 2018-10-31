//
//  OCLogger.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.03.18.
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

#import "OCLogger.h"
#import "OCLogWriter.h"
#import "OCLogFileWriter.h"
#import <pthread/pthread.h>

static OCLogLevel sOCLogLevel;
static BOOL sOCLogMaskPrivateData;

@interface OCLogger ()
{
	uint64_t _mainThreadThreadID;
}
@end

@implementation OCLogger

+ (instancetype)sharedLogger
{
	static dispatch_once_t onceToken;
	static OCLogger *sharedLogger;

	dispatch_once(&onceToken, ^{
		sharedLogger = [OCLogger new];

		[sharedLogger addWriter:[OCLogWriter new]];
		[sharedLogger addWriter:[OCLogFileWriter new]];
	});
	
	return (sharedLogger);
}

+ (OCLogLevel)logLevel
{
	return (sOCLogLevel);
}

+ (void)setLogLevel:(OCLogLevel)newLogLevel
{
	sOCLogLevel = newLogLevel;
}

+ (BOOL)maskPrivateData
{
	return (sOCLogMaskPrivateData);
}

+ (void)setMaskPrivateData:(BOOL)maskPrivateData
{
	sOCLogMaskPrivateData = maskPrivateData;
}

#pragma mark - Init
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_writers = [NSMutableArray new];
		_writerQueue = dispatch_queue_create("OCLogger writer queue", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
	}

	return (self);
}

- (void)dealloc
{
	[self _closeAllWriters];
}

#pragma mark - Logging
- (void)appendLogLevel:(OCLogLevel)logLevel functionName:(NSString *)functionName file:(NSString *)file line:(NSUInteger)line message:(NSString *)formatString, ...
{
	if (logLevel >= sOCLogLevel)
	{
		va_list args;

		va_start(args, formatString);
		[self appendLogLevel:logLevel functionName:functionName file:file line:line message:formatString arguments:args];
		va_end(args);
	}
}

- (void)appendLogLevel:(OCLogLevel)logLevel functionName:(NSString *)functionName file:(NSString *)file line:(NSUInteger)line message:(NSString *)formatString arguments:(va_list)args
{
	if (logLevel >= sOCLogLevel)
	{
		NSString *logMessage;
		NSDate *timestamp;
		uint64_t threadID = 0, mainThreadID = 0;
		// mach_port_t rawThreadID = pthread_mach_thread_np(pthread_self());

		pthread_threadid_np(pthread_self(), &threadID);

		if (_mainThreadThreadID == 0)
		{
			if (pthread_main_np() != 0)
			{
				_mainThreadThreadID = threadID;
			}
		}

		mainThreadID = _mainThreadThreadID;

		timestamp = [NSDate date];
		logMessage = [[NSString alloc] initWithFormat:formatString arguments:args];

		dispatch_async(_writerQueue, ^{
			for (OCLogWriter *writer in self->_writers)
			{
				if (writer.isOpen)
				{
					[writer appendMessageWithLogLevel:logLevel date:timestamp threadID:threadID isMainThread:(threadID==mainThreadID) privacyMasked:sOCLogMaskPrivateData functionName:functionName file:file line:line message:logMessage];
				}
			}
		});
	}
}

+ (id)applyPrivacyMask:(id)object
{
	if (sOCLogMaskPrivateData && (object!=nil))
	{
		// Remove userInfo for NSErrors
		if ([object isKindOfClass:[NSError class]])
		{
			NSError *error = object;
			
			return ([NSError errorWithDomain:error.domain code:error.code userInfo:nil]);
		}
	
		// Return «private» for all other objects that should be privacy masked
		return (@"«private»");
	}

	return (object);
}

#pragma mark - Writers
- (void)addWriter:(OCLogWriter *)logWriter
{
	dispatch_async(_writerQueue, ^{
		NSError *error;

		if ((error = [logWriter open]) == nil)
		{
			[self->_writers addObject:logWriter];
		}
		else
		{
			NSLog(@"Did not add log writer %@: couldn't be opened due to error %@", logWriter, error);
		}
	});
}

- (void)pauseWritersWithIntermittentBlock:(dispatch_block_t)intermittentBlock
{
	dispatch_async(_writerQueue, ^{
		[self _closeAllWriters];

		intermittentBlock();

		[self _openAllWriters];
	});
}

- (void)_openAllWriters
{
	for (OCLogWriter *writer in _writers)
	{
		if (!writer.isOpen)
		{
			NSError *error;

			if ((error = [writer open]) != nil)
			{
				NSLog(@"Error opening log writer %@: %@", writer, error);
			}
		}
	}
}

- (void)_closeAllWriters
{
	for (OCLogWriter *writer in _writers)
	{
		if (writer.isOpen)
		{
			NSError *error;

			if ((error = [writer close]) != nil)
			{
				NSLog(@"Error closing log writer %@: %@", writer, error);
			}
		}
	}
}

@end
