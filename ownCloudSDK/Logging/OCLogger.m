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
#import "OCLogSource.h"
#import "OCLogFileSource.h"
#import "OCAppIdentity.h"
#import "OCIPNotificationCenter.h"
#import <pthread/pthread.h>

static OCLogLevel sOCLogLevel;
static BOOL sOCLogLevelInitialized;

static BOOL sOCLogMaskPrivateData;
static BOOL sOCLogMaskPrivateDataInitialized;

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
		OCLogFileSource *stdErrLogger;

		sharedLogger = [OCLogger new];

		if ((stdErrLogger = [[OCLogFileSource alloc] initWithFILE:stderr name:@"stderr" logger:sharedLogger]) != nil)
		{
			__weak OCLogFileSource *weakStdErrLogger = stdErrLogger;

			[sharedLogger addSource:stdErrLogger];

			[sharedLogger addWriter:[[OCLogWriter alloc] initWithWriteHandler:^(NSString * _Nonnull message) {
				[weakStdErrLogger writeDataToOriginalFile:[message dataUsingEncoding:NSUTF8StringEncoding]];
			}]];
		}
		else
		{
			[sharedLogger addWriter:[[OCLogWriter alloc] initWithWriteHandler:^(NSString * _Nonnull message) {
				fwrite([message UTF8String], [message lengthOfBytesUsingEncoding:NSUTF8StringEncoding], 1, stderr);
				fflush(stderr);
			}]];
		}

		[sharedLogger addWriter:[OCLogFileWriter new]];
	});
	
	return (sharedLogger);
}

#pragma mark - Class settings
+ (OCClassSettingsIdentifier)classSettingsIdentifier
{
	return (OCClassSettingsIdentifierLog);
}

+ (NSDictionary<OCClassSettingsKey,id> *)defaultSettingsForIdentifier:(OCClassSettingsIdentifier)identifier
{
	if ([identifier isEqual:OCClassSettingsIdentifierLog])
	{
		return (@{
			OCClassSettingsKeyLogLevel		: @(OCLogLevelDebug),
			OCClassSettingsKeyLogPrivacyMask	: @(NO),
			OCClassSettingsKeyLogEnabledWriters	: @[ OCLogWriterIdentifierStandardError ]
		});
	}

	return (nil);
}

#pragma mark - Settings
+ (OCLogLevel)logLevel
{
	if (!sOCLogLevelInitialized)
	{
		NSNumber *logLevelNumber = nil;

		if ((logLevelNumber = [OCAppIdentity.sharedAppIdentity.userDefaults objectForKey:OCClassSettingsKeyLogLevel]) == nil)
		{
			logLevelNumber = [self classSettingForOCClassSettingsKey:OCClassSettingsKeyLogLevel];
		}

		if (logLevelNumber != nil)
		{
			sOCLogLevel = [logLevelNumber integerValue];
		}
		else
		{
			sOCLogLevel = OCLogLevelOff;
		}

		sOCLogLevelInitialized = YES;
	}

	return (sOCLogLevel);
}

+ (void)setLogLevel:(OCLogLevel)newLogLevel
{
	sOCLogLevel = newLogLevel;

	[OCAppIdentity.sharedAppIdentity.userDefaults setInteger:newLogLevel forKey:OCClassSettingsKeyLogLevel];

	[OCIPNotificationCenter.sharedNotificationCenter postNotificationForName:OCIPCNotificationNameLogSettingsChanged ignoreSelf:YES];
}

+ (BOOL)maskPrivateData
{
	if (!sOCLogMaskPrivateDataInitialized)
	{
		NSNumber *maskPrivateDataNumber = nil;

		if ((maskPrivateDataNumber = [OCAppIdentity.sharedAppIdentity.userDefaults objectForKey:OCClassSettingsKeyLogPrivacyMask]) == nil)
		{
			maskPrivateDataNumber = [self classSettingForOCClassSettingsKey:OCClassSettingsKeyLogPrivacyMask];
		}

		if (maskPrivateDataNumber != nil)
		{
			sOCLogMaskPrivateData = maskPrivateDataNumber.boolValue;
		}
		else
		{
			sOCLogMaskPrivateData = YES;
		}

		sOCLogMaskPrivateDataInitialized = YES;
	}

	return (sOCLogMaskPrivateData);
}

+ (void)setMaskPrivateData:(BOOL)maskPrivateData
{
	sOCLogMaskPrivateData = maskPrivateData;

	[OCAppIdentity.sharedAppIdentity.userDefaults setBool:maskPrivateData forKey:OCClassSettingsKeyLogPrivacyMask];

	[OCIPNotificationCenter.sharedNotificationCenter postNotificationForName:OCIPCNotificationNameLogSettingsChanged ignoreSelf:YES];
}

#pragma mark - Init
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_writers = [NSMutableArray new];
		_writerQueue = dispatch_queue_create("OCLogger writer queue", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);

		_sources = [NSMutableArray new];

		dispatch_async(dispatch_get_main_queue(), ^{
			// Determine main thread ID
			if (pthread_main_np() != 0)
			{
				uint64_t mainThreadID;

				pthread_threadid_np(pthread_self(), &mainThreadID);

				self->_mainThreadThreadID = mainThreadID;
			}
		});

		[OCIPNotificationCenter.sharedNotificationCenter addObserver:self forName:OCIPCNotificationNameLogSettingsChanged withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, OCLogger * _Nonnull logger, OCIPCNotificationName  _Nonnull notificationName) {
			sOCLogLevelInitialized = NO;
			sOCLogMaskPrivateDataInitialized = NO;
		}];
	}

	return (self);
}

- (void)dealloc
{
	[OCIPNotificationCenter.sharedNotificationCenter removeObserver:self forName:OCIPCNotificationNameLogSettingsChanged];

	[self _closeAllWriters];

	for (OCLogSource *source in _sources)
	{
		[source stop];
	}
}

#pragma mark - Logging
- (void)appendLogLevel:(OCLogLevel)logLevel functionName:(NSString *)functionName file:(NSString *)file line:(NSUInteger)line message:(NSString *)formatString, ...
{
	if (logLevel >= OCLogger.logLevel)
	{
		va_list args;

		va_start(args, formatString);
		[self appendLogLevel:logLevel functionName:functionName file:file line:line message:formatString arguments:args];
		va_end(args);
	}
}

- (void)appendLogLevel:(OCLogLevel)logLevel functionName:(NSString *)functionName file:(NSString *)file line:(NSUInteger)line message:(NSString *)formatString arguments:(va_list)args
{
	if (logLevel >= OCLogger.logLevel)
	{
		NSString *logMessage;
		NSDate *timestamp;
		uint64_t threadID = 0;

		pthread_threadid_np(pthread_self(), &threadID);

		if (_mainThreadThreadID == 0)
		{
			if (pthread_main_np() != 0)
			{
				_mainThreadThreadID = threadID;
			}
		}

		timestamp = [NSDate date];
		logMessage = [[NSString alloc] initWithFormat:formatString arguments:args];

		[self rawAppendLogLevel:logLevel functionName:functionName file:file line:line logMessage:logMessage threadID:threadID timestamp:timestamp];
	}
}

- (void)rawAppendLogLevel:(OCLogLevel)logLevel functionName:(NSString * _Nullable)functionName file:(NSString * _Nullable)file line:(NSUInteger)line logMessage:(NSString *)logMessage threadID:(uint64_t)threadID timestamp:(NSDate *)timestamp
{
	dispatch_async(_writerQueue, ^{
		for (OCLogWriter *writer in self->_writers)
		{
			if (writer.enabled)
			{
				if (!writer.isOpen)
				{
					NSError *error;

					if ((error = [writer open]) != nil)
					{
						NSLog(@"Error opening writer %@: %@", writer, error);
					}
				}

				if (writer.isOpen)
				{
					[writer appendMessageWithLogLevel:logLevel date:timestamp threadID:threadID isMainThread:(threadID==self->_mainThreadThreadID) privacyMasked:sOCLogMaskPrivateData functionName:functionName file:file line:line message:logMessage];
				}
			}
			else
			{
				if (writer.isOpen)
				{
					NSError *error;

					if ((error = [writer close]) != nil)
					{
						NSLog(@"Error closing writer %@: %@", writer, error);
					}
				}
			}
		}
	});
}

+ (id)applyPrivacyMask:(id)object
{
	if (self.maskPrivateData && (object!=nil))
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

#pragma mark - Sources
- (void)addSource:(OCLogSource *)logSource
{
	@synchronized(self)
	{
		[_sources addObject:logSource];
		[logSource start];
	}
}

- (void)removeSource:(OCLogSource *)logSource
{
	@synchronized(self)
	{
		[logSource stop];
		[_sources removeObject:logSource];
	}
}

#pragma mark - Writers
- (void)addWriter:(OCLogWriter *)logWriter
{
	dispatch_async(_writerQueue, ^{
		[self->_writers addObject:logWriter];
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

- (NSArray<OCLogWriter *> *)writers
{
	return ([NSArray arrayWithArray:_writers]);
}

- (nullable OCLogWriter *)writerWithIdentifier:(OCLogWriterIdentifier)identifier
{
	for (OCLogWriter *writer in _writers)
	{
		if ([writer.identifier isEqual:identifier])
		{
			return (writer);
		}
	}

	return (nil);
}

- (void)_openAllWriters
{
	for (OCLogWriter *writer in _writers)
	{
		if (!writer.isOpen && writer.enabled)
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

OCClassSettingsIdentifier OCClassSettingsIdentifierLog = @"log";

OCClassSettingsKey OCClassSettingsKeyLogLevel = @"log--level";
OCClassSettingsKey OCClassSettingsKeyLogPrivacyMask = @"log--privacy-mask";
OCClassSettingsKey OCClassSettingsKeyLogEnabledWriters = @"log--enabled-writers";

OCIPCNotificationName OCIPCNotificationNameLogSettingsChanged = @"org.owncloud.log-settings-changed";
