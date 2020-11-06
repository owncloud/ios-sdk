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

#import <UIKit/UIKit.h>
#import <sys/utsname.h>

#import "OCLogger.h"
#import "OCLogWriter.h"
#import "OCLogFileWriter.h"
#import "OCLogSource.h"
#import "OCLogFileSource.h"
#import "OCAppIdentity.h"
#import "OCIPNotificationCenter.h"
#import "OCMacros.h"
#import <pthread/pthread.h>

#import "OCConnection.h"
#import "OCCore.h"

static OCLogLevel sOCLogLevel;
static BOOL sOCLogLevelInitialized;

static BOOL sOCLogMaskPrivateData;
static BOOL sOCLogMaskPrivateDataInitialized;

static OCLogFormat sOCLogFormat;
static BOOL sOCLogSingleLined;
static NSUInteger sOCLogMessageMaximumSize;

@interface OCLogger ()
{
	uint64_t _mainThreadThreadID;
}
@end

static OCClassSettingsUserPreferencesMigrationIdentifier OCClassSettingsUserPreferencesMigrationIdentifierLogLevel = @"log-level";

@implementation OCLogger

+ (instancetype)sharedLogger
{
	static dispatch_once_t onceToken;
	static OCLogger *sharedLogger;

	dispatch_once(&onceToken, ^{
		OCLogFileSource *stdErrLogger;

		sharedLogger = [OCLogger new];

		if ((stdErrLogger = [[OCLogFileSource alloc] initWithFILE:stderr name:@"OS" logger:sharedLogger]) != nil)
		{
			__weak OCLogFileSource *weakStdErrLogger = stdErrLogger;

			[sharedLogger addSource:stdErrLogger];

			[sharedLogger addWriter:[[OCLogWriter alloc] initWithWriteHandler:^(NSData * _Nonnull messageData) {
				[weakStdErrLogger writeDataToOriginalFile:messageData];
			}]];
		}
		else
		{
			[sharedLogger addWriter:[[OCLogWriter alloc] initWithWriteHandler:^(NSData * _Nonnull messageData) {
				fwrite(messageData.bytes, messageData.length, 1, stderr);
				fflush(stderr);
			}]];
		}

		[sharedLogger addWriter:[OCLogFileWriter new]];

		[sharedLogger addToggle:[[OCLogToggle alloc] initWithIdentifier:OCLogOptionLogRequestsAndResponses localizedName:OCLocalizedString(@"Log HTTP requests and responses", nil)]];

		NSSet<NSString *> *(^ConvertTagArrayToTagSet)(NSArray *tags) = ^NSSet<NSString *> *(NSArray<NSString *> *tags) {
			if ((tags==nil) || ([tags isKindOfClass:[NSArray class]] && (tags.count == 0)))
			{
				return (nil);
			}

			return ([[NSSet alloc] initWithArray:tags]);
		};
		NSSet<NSString *> *onlyTagsSet = nil, *omitTagsSet = nil, *onlyMatchingSet = nil, *omitMatchingSet = nil;
		BOOL blankFilteredMessages = ((NSNumber *)[self classSettingForOCClassSettingsKey:OCClassSettingsKeyLogBlankFilteredMessages]).boolValue;

		onlyTagsSet = ConvertTagArrayToTagSet([self classSettingForOCClassSettingsKey:OCClassSettingsKeyLogOnlyTags]);
		omitTagsSet = ConvertTagArrayToTagSet([self classSettingForOCClassSettingsKey:OCClassSettingsKeyLogOmitTags]);
		onlyMatchingSet = ConvertTagArrayToTagSet([self classSettingForOCClassSettingsKey:OCClassSettingsKeyLogOnlyMatching]);
		omitMatchingSet = ConvertTagArrayToTagSet([self classSettingForOCClassSettingsKey:OCClassSettingsKeyLogOmitMatching]);

		if ((onlyTagsSet != nil) || (omitTagsSet != nil) || (onlyMatchingSet != nil) || (omitMatchingSet != nil))
		{
			[sharedLogger addFilter:^BOOL(OCLogger * _Nonnull logger, OCLogLevel logLevel, NSString * _Nullable functionName, NSString * _Nullable file, NSUInteger line, NSArray<OCLogTagName> ** _Nullable pTags, NSString *__autoreleasing *pLogMessage, uint64_t threadID, NSDate * _Nonnull timestamp) {
				NSSet<OCLogTagName> *tagSet = (((pTags!=NULL) && (*pTags != nil)) ? [[NSSet alloc] initWithArray:*pTags] : nil);
				BOOL allowMessage = YES;

				if ((omitTagsSet != nil) && (tagSet != nil))
				{
					// Omit messages tagged with tags in omitTagsSet
					if ([omitTagsSet intersectsSet:tagSet])
					{
						allowMessage = NO;
					}
				}

				if ((allowMessage==YES) && (omitMatchingSet != nil))
				{
					// Omit messages containing any of the exact terms in omitMatchingSet
					for (NSString *term in omitMatchingSet)
					{
						if ([*pLogMessage containsString:term])
						{
							allowMessage = NO;
							break;
						}
					}
				}

				if ((allowMessage==YES) && (onlyTagsSet != nil))
				{
					if (tagSet==nil)
					{
						// Omit messages without tags
						allowMessage = NO;
					}
					else if (![tagSet intersectsSet:onlyTagsSet])
					{
						// Only log messages if tagSet contains any of the tags in onlyTagsSet
						allowMessage = NO;
					}
				}

				if ((allowMessage==YES) && (onlyMatchingSet != nil))
				{
					BOOL containsAtLeastOne = YES;

					for (NSString *term in onlyMatchingSet)
					{
						if ([*pLogMessage containsString:term])
						{
							containsAtLeastOne = YES;
							break;
						}
					}

					if (!containsAtLeastOne)
					{
						// Only log messages if they contain one or more of the exact terms in onlyMatchingSet
						allowMessage = NO;
					}
				}

				if (!allowMessage && blankFilteredMessages)
				{
					*pLogMessage = @"-";
					allowMessage = YES;
				}

				return (allowMessage);
			}];
		}

		OCIPNotificationCenter.loggingEnabled = ![[self classSettingForOCClassSettingsKey:OCClassSettingsKeyLogSynchronousLogging] boolValue];
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
			OCClassSettingsKeyLogLevel		   : @(OCLogLevelOff),
			OCClassSettingsKeyLogPrivacyMask	   : @(NO),
			OCClassSettingsKeyLogEnabledComponents	   : @[ OCLogComponentIdentifierWriterStandardError, OCLogComponentIdentifierWriterFile, OCLogOptionLogRequestsAndResponses ],
			OCClassSettingsKeyLogSynchronousLogging    : @(NO),
			OCClassSettingsKeyLogBlankFilteredMessages : @(NO),
			OCClassSettingsKeyLogColored		   : @(NO),
			OCClassSettingsKeyLogSingleLined	   : @(YES),
			OCClassSettingsKeyLogMaximumLogMessageSize : @(0),
			OCClassSettingsKeyLogFormat		   : @"text"
		});
	}

	return (nil);
}

+ (BOOL)allowUserPreferenceForClassSettingsKey:(OCClassSettingsKey)key
{
	return ([key isEqual:OCClassSettingsKeyLogLevel]);
}

#pragma mark - Settings
+ (OCLogLevel)logLevel
{
	if (!sOCLogLevelInitialized)
	{
		NSNumber *logLevelNumber = nil;

		// Migrate log level setting from UserDefaults to OCClassSettingsUserPreferences
		[OCClassSettingsUserPreferences migrateWithIdentifier:OCClassSettingsUserPreferencesMigrationIdentifierLogLevel version:@(1) silent:YES perform:^NSError * _Nullable(OCClassSettingsUserPreferencesMigrationVersion  _Nullable lastMigrationVersion) {
			NSNumber *userDefaultsLogLevel;

			if ((userDefaultsLogLevel = [OCAppIdentity.sharedAppIdentity.userDefaults objectForKey:OCClassSettingsKeyLogLevel]) != nil)
			{
				[self setUserPreferenceValue:userDefaultsLogLevel forClassSettingsKey:OCClassSettingsKeyLogLevel];

				[OCAppIdentity.sharedAppIdentity.userDefaults removeObjectForKey:OCClassSettingsKeyLogLevel];
			}

			return (nil);
		}];

		if ((logLevelNumber = [self classSettingForOCClassSettingsKey:OCClassSettingsKeyLogLevel]) != nil)
		{
			sOCLogLevel = [logLevelNumber integerValue];
		}
		else
		{
			sOCLogLevel = OCLogLevelOff;
		}

		sOCLogSingleLined = [[self classSettingForOCClassSettingsKey:OCClassSettingsKeyLogSingleLined] boolValue];

		sOCLogMessageMaximumSize = [[self classSettingForOCClassSettingsKey:OCClassSettingsKeyLogMaximumLogMessageSize] unsignedIntegerValue];

		sOCLogFormat = [self logFormat]; // must be called before setting sOCLogLevelInitialized to YES
		if ((sOCLogFormat == OCLogFormatJSON) || (sOCLogFormat == OCLogFormatJSONComposed))
		{
			sOCLogSingleLined = NO; // override single lined if log format is JSON to permanently off
		}

		sOCLogLevelInitialized = YES;
	}

	return (sOCLogLevel);
}

+ (void)setLogLevel:(OCLogLevel)newLogLevel
{
	sOCLogLevel = newLogLevel;

	[self setUserPreferenceValue:@(newLogLevel) forClassSettingsKey:OCClassSettingsKeyLogLevel];

	[OCIPNotificationCenter.sharedNotificationCenter postNotificationForName:OCIPCNotificationNameLogSettingsChanged ignoreSelf:YES];

	OCPFSLog(nil, (@[@"LogIntro"]), @"Log level changed to %ld", (long)sOCLogLevel);
	OCPFSLog(nil, (@[@"LogIntro"]), @"%@", OCLogger.sharedLogger.logIntro);
}

+ (OCLogFormat)logFormat
{
	if (!sOCLogLevelInitialized)
	{
		NSString *logFormatString;

		if ((logFormatString = [self classSettingForOCClassSettingsKey:OCClassSettingsKeyLogFormat]) != nil)
		{
			if ([logFormatString isEqual:@"text"])
			{
				return (OCLogFormatText);
			}

			if ([logFormatString isEqual:@"json"])
			{
				return (OCLogFormatJSON);
			}

			if ([logFormatString isEqual:@"json-composed"])
			{
				return (OCLogFormatJSONComposed);
			}
		}

		return (OCLogFormatText);
	}

	return (sOCLogFormat);
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

+ (BOOL)coloredLogging
{
	static BOOL coloredLog;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		coloredLog = [[self classSettingForOCClassSettingsKey:OCClassSettingsKeyLogColored] boolValue];
	});

	return (coloredLog);
}

+ (BOOL)synchronousLoggingEnabled
{
	static dispatch_once_t onceToken;
	static BOOL synchronousLoggingEnabled = NO;

	dispatch_once(&onceToken, ^{
		synchronousLoggingEnabled = ((NSNumber *)[self classSettingForOCClassSettingsKey:OCClassSettingsKeyLogSynchronousLogging]).boolValue;

		if (synchronousLoggingEnabled)
		{
			NSLog(@"[LOG] Synchronous logging enabled");
		}
	});

	return (synchronousLoggingEnabled);
}

#pragma mark - Init
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_writers = [NSMutableArray new];
		_writeQueue = dispatch_queue_create("OCLogger writer queue", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);

		_sources = [NSMutableArray new];

		_togglesByIdentifier = [NSMutableDictionary new];
		_toggles = [NSMutableArray new];

		dispatch_async(dispatch_get_main_queue(), ^{
			// Determine main thread ID
			if (pthread_main_np() != 0)
			{
				uint64_t mainThreadID;

				pthread_threadid_np(pthread_self(), &mainThreadID);

				self->_mainThreadThreadID = mainThreadID;
			}
		});

		// Register log settings listener
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

#pragma mark - Conditions
+ (BOOL)logsForLevel:(OCLogLevel)level
{
	return (sOCLogLevel <= level);
}

#pragma mark - Logging
- (void)appendLogLevel:(OCLogLevel)logLevel functionName:(NSString *)functionName file:(NSString *)file line:(NSUInteger)line tags:(nullable NSArray<OCLogTagName> *)tags message:(NSString *)formatString, ...
{
	if ([OCLogger logsForLevel:logLevel])
	{
		va_list args;

		va_start(args, formatString);
		[self appendLogLevel:logLevel force:NO forceSyncWrite:NO functionName:functionName file:file line:line tags:tags message:formatString arguments:args];
		va_end(args);
	}
}

- (void)appendLogLevel:(OCLogLevel)logLevel force:(BOOL)force forceSyncWrite:(BOOL)forceSyncWrite functionName:(nullable NSString *)functionName file:(nullable NSString *)file line:(NSUInteger)line tags:(nullable NSArray<OCLogTagName> *)tags message:(NSString *)formatString, ...
{
	if ([OCLogger logsForLevel:logLevel] || (force && OCLoggingEnabled()))
	{
		va_list args;

		va_start(args, formatString);
		[self appendLogLevel:logLevel force:force forceSyncWrite:forceSyncWrite functionName:functionName file:file line:line tags:tags message:formatString arguments:args];
		va_end(args);
	}
}

- (void)appendLogLevel:(OCLogLevel)logLevel functionName:(NSString *)functionName file:(NSString *)file line:(NSUInteger)line tags:(NSArray<OCLogTagName> *)tags message:(NSString *)formatString arguments:(va_list)args
{
	[self appendLogLevel:logLevel force:NO forceSyncWrite:NO functionName:functionName file:file line:line tags:tags message:formatString arguments:args];
}

- (void)appendLogLevel:(OCLogLevel)logLevel force:(BOOL)force forceSyncWrite:(BOOL)forceSyncWrite functionName:(NSString *)functionName file:(NSString *)file line:(NSUInteger)line tags:(nullable NSArray<OCLogTagName> *)tags message:(NSString *)formatString arguments:(va_list)args
{
	if ([OCLogger logsForLevel:logLevel] || (force && OCLoggingEnabled()))
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

		[self rawAppendLogLevel:logLevel functionName:functionName file:file line:line tags:tags logMessage:logMessage threadID:threadID timestamp:timestamp forceSyncWrite:forceSyncWrite];
	}
}

- (void)rawAppendLogLevel:(OCLogLevel)logLevel functionName:(NSString * _Nullable)functionName file:(NSString * _Nullable)file line:(NSUInteger)line tags:(nullable NSArray<OCLogTagName> *)tags logMessage:(NSString *)logMessage threadID:(uint64_t)threadID timestamp:(NSDate *)timestamp forceSyncWrite:(BOOL)forceSyncWrite
{
	if (OCLogger.synchronousLoggingEnabled || forceSyncWrite)
	{
		@synchronized(self)
		{
			[self _rawAppendLogLevel:logLevel functionName:functionName file:file line:line tags:tags logMessage:logMessage threadID:threadID timestamp:timestamp];
		}
	}
	else
	{
		dispatch_async(_writeQueue, ^{
			[self _rawAppendLogLevel:logLevel functionName:functionName file:file line:line tags:tags logMessage:logMessage threadID:threadID timestamp:timestamp];
		});
	}
}

- (void)_rawAppendLogLevel:(OCLogLevel)logLevel functionName:(NSString * _Nullable)functionName file:(NSString * _Nullable)file line:(NSUInteger)line tags:(nullable NSArray<OCLogTagName> *)tags logMessage:(NSString *)logMessage threadID:(uint64_t)threadID timestamp:(NSDate *)timestamp
{
	if (_filter != nil)
	{
		if (!_filter(self, logLevel, functionName, file, line, &tags, &logMessage, threadID, timestamp))
		{
			return;
		}
	}

	if (sOCLogMessageMaximumSize != 0)
	{
		if (logMessage.length > sOCLogMessageMaximumSize)
		{
			logMessage = [[logMessage substringToIndex:sOCLogMessageMaximumSize] stringByAppendingFormat:@" [truncated: %lu -> %lu bytes]", logMessage.length, sOCLogMessageMaximumSize];
		}
	}

	NSArray<NSString *> *lines = nil;

	if (sOCLogSingleLined)
	{
		static NSString *splitNewLine;
		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			splitNewLine = [[NSString alloc] initWithFormat:@"\n"];
		});

		lines = [logMessage componentsSeparatedByString:splitNewLine];
	}

	for (OCLogWriter *writer in self->_writers)
	{
		if ((sOCLogLevel != OCLogLevelOff) && writer.enabled)
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
				if (lines != nil)
				{
					NSUInteger lineIdx = 0, linesLastIdx = lines.count - 1;
					OCLogLineFlag lineFlags = OCLogLineFlagSingleLinesModeEnabled | ((linesLastIdx > 1) ? OCLogLineFlagTotalLineCountGreaterTwo : 0);

					for (NSString *singleLine in lines)
					{
						[writer appendMessageWithLogLevel:logLevel
									     date:timestamp
									 threadID:threadID
								     isMainThread:(threadID==self->_mainThreadThreadID)
								    privacyMasked:sOCLogMaskPrivateData
								     functionName:functionName
									     file:file
									     line:line
									     tags:tags
									    flags:(	lineFlags |
									    		((lineIdx == 0) ? OCLogLineFlagLineFirst : 0) |
									    		((lineIdx == linesLastIdx) ? OCLogLineFlagLineLast : 0) |
									    		((lineIdx > 0) && (lineIdx < linesLastIdx) ? OCLogLineFlagLineInbetween : 0)
										  )
									  message:singleLine];

						lineIdx++;
					}
				}
				else
				{
					[writer appendMessageWithLogLevel:logLevel date:timestamp threadID:threadID isMainThread:(threadID==self->_mainThreadThreadID) privacyMasked:sOCLogMaskPrivateData functionName:functionName file:file line:line tags:tags flags:(OCLogLineFlagLineFirst|OCLogLineFlagLineLast) message:logMessage];
				}
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

		// Condense other types
		if ([object conformsToProtocol:@protocol(OCLogPrivacyMasking)])
		{
			return ([(id <OCLogPrivacyMasking>)object privacyMaskedDescription]);
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

#pragma mark - Filters
- (void)addFilter:(OCLogFilter)filter
{
	if (filter == nil) { return; }

	filter = [filter copy];

	@synchronized(self)
	{
		if (_filter != nil)
		{
			OCLogFilter previousFilter = _filter;
			OCLogFilter newFilter = filter;

			filter = [^BOOL(OCLogger * _Nonnull logger, OCLogLevel logLevel, NSString * _Nullable functionName, NSString * _Nullable file, NSUInteger line, NSArray<OCLogTagName> ** _Nullable pTags, NSString *__autoreleasing *pLogMessage, uint64_t threadID, NSDate * _Nonnull timestamp) {
				if (newFilter(logger, logLevel, functionName, file, line, pTags, pLogMessage, threadID, timestamp))
				{
					return previousFilter(logger, logLevel, functionName, file, line, pTags, pLogMessage, threadID, timestamp);
				}
				return (NO);
			} copy];
		}

		_filter = filter;
	}
}

#pragma mark - Writers
- (void)addWriter:(OCLogWriter *)logWriter
{
	dispatch_async(_writeQueue, ^{
		[self->_writers addObject:logWriter];
	});
}

- (void)pauseWritersWithIntermittentBlock:(dispatch_block_t)intermittentBlock
{
	dispatch_async(_writeQueue, ^{
		[self _closeAllWriters];

		intermittentBlock();

		[self _openAllWriters];
	});
}

- (NSArray<OCLogWriter *> *)writers
{
	return ([NSArray arrayWithArray:_writers]);
}

- (nullable OCLogWriter *)writerWithIdentifier:(OCLogComponentIdentifier)identifier
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
	if (!OCLoggingEnabled())
	{
		// Logging is not enabled, so writer would not otherwise be opened
		// Writers will be opened when the first message hits the write pipeline
		return;
	}

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

#pragma mark - Toggles
- (void)addToggle:(OCLogToggle *)logToggle
{
	if ((logToggle!=nil) && (logToggle.identifier != nil))
	{
		@synchronized(self)
		{
			if (_togglesByIdentifier[logToggle.identifier] == nil)
			{
				_togglesByIdentifier[logToggle.identifier] = logToggle;
				[_toggles addObject:logToggle];
			}
		}
	}
}

- (NSArray<OCLogToggle *> *)toggles
{
	@synchronized(self)
	{
		return ([NSArray arrayWithArray:_toggles]);
	}
}

- (BOOL)isToggleEnabled:(OCLogComponentIdentifier)toggleIdentifier
{
	@synchronized(self)
	{
		return (_togglesByIdentifier[toggleIdentifier].enabled);
	}
}

#pragma mark - Log intro
- (NSString *)logIntro
{
	static NSString *cachedLogIntro;
	NSString *logIntro = nil;

	@synchronized(self)
	{
		if (cachedLogIntro == nil)
		{
			NSBundle *mainBundle = [NSBundle mainBundle];

			NSString *deviceModelID = @"";
			NSString *logHostCommit = @"";
			struct utsname utsNames;
			if (uname(&utsNames) >= 0)
			{
				deviceModelID = [NSString stringWithFormat:@" (%@)", [NSString stringWithUTF8String:utsNames.machine]];
			}

			if ([self respondsToSelector:@selector(logHostCommit)])
			{
				NSString *hostCommit;

				if ((hostCommit = [((id<OCLogIntroFormat>)self) logHostCommit]) != nil)
				{
					logHostCommit = [NSString stringWithFormat:@" #%@", hostCommit];
				}
			}

			logIntro = [NSString stringWithFormat:@"Host: %@ %@ (%@)%@; SDK: %@; OS: %@ %@; Device: %@%@; Localizations: [%@]; Class Setttings: %@",
				[mainBundle bundleIdentifier], // Bundle ID
				[mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"], // Version
				[mainBundle objectForInfoDictionaryKey:(__bridge NSString *)kCFBundleVersionKey], // Build version
				logHostCommit,
				OCAppIdentity.sharedAppIdentity.sdkVersionString, // SDK version
				UIDevice.currentDevice.systemName, UIDevice.currentDevice.systemVersion, // OS name + version
				UIDevice.currentDevice.model, // Device model
				deviceModelID, // Device model ID
				[[mainBundle preferredLocalizations] componentsJoinedByString:@", "],  // Localizations
				[OCClassSettings.sharedSettings settingsSummaryForClasses:@[ OCConnection.class, OCCore.class, OCLogger.class, OCHTTPPipeline.class, OCAuthenticationMethod.class ] onlyPublic:YES]  // Class Settings
			];

			cachedLogIntro = logIntro;
		}
		else
		{
			logIntro = cachedLogIntro;
		}

		if ([self conformsToProtocol:@protocol(OCLogIntroFormat)])
		{
			NSString *logIntroFormat;

			if ((logIntroFormat = [((id<OCLogIntroFormat>)self) logIntroFormat]) != nil)
			{
				logIntro = [logIntroFormat stringByReplacingOccurrencesOfString:@"{{stdIntro}}" withString:logIntro];
			}
		}
	}

	return (logIntro);
}

@end

@implementation NSArray (OCLogTagMerge)

- (NSArray<NSString *> *)arrayByMergingTagsFromArray:(NSArray<NSString *> *)mergeTags
{
	if (self.count < 2)
	{
		return ([self arrayByAddingObjectsFromArray:mergeTags]);
	}

	NSMutableArray<NSString *> *mergedTags = [[NSMutableArray alloc] initWithCapacity:(self.count+mergeTags.count)];

	[mergedTags addObjectsFromArray:self];

	NSUInteger mergedTagsCount = mergedTags.count;

	for (NSUInteger idx=0; idx < mergeTags.count; idx++)
	{
		[mergedTags insertObject:mergedTags[idx] atIndex:((idx == 0) ? 1 : mergedTagsCount)];

		mergedTagsCount++;
	}

	return (mergeTags);
}

@end

OCClassSettingsIdentifier OCClassSettingsIdentifierLog = @"log";

OCClassSettingsKey OCClassSettingsKeyLogLevel = @"log-level";
OCClassSettingsKey OCClassSettingsKeyLogPrivacyMask = @"log-privacy-mask";
OCClassSettingsKey OCClassSettingsKeyLogEnabledComponents = @"log-enabled-components";
OCClassSettingsKey OCClassSettingsKeyLogSynchronousLogging = @"log-synchronous";
OCClassSettingsKey OCClassSettingsKeyLogColored = @"log-colored";
OCClassSettingsKey OCClassSettingsKeyLogOnlyTags = @"log-only-tags";
OCClassSettingsKey OCClassSettingsKeyLogOmitTags = @"log-omit-tags";
OCClassSettingsKey OCClassSettingsKeyLogOnlyMatching = @"log-only-matching";
OCClassSettingsKey OCClassSettingsKeyLogOmitMatching = @"log-omit-matching";
OCClassSettingsKey OCClassSettingsKeyLogBlankFilteredMessages = @"log-blank-filtered-messages";
OCClassSettingsKey OCClassSettingsKeyLogSingleLined = @"log-single-lined";
OCClassSettingsKey OCClassSettingsKeyLogMaximumLogMessageSize = @"log-maximum-message-size";
OCClassSettingsKey OCClassSettingsKeyLogFormat = @"log-format";

OCIPCNotificationName OCIPCNotificationNameLogSettingsChanged = @"org.owncloud.log-settings-changed";
