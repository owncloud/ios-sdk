//
//  OCLogger.h
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

#import <Foundation/Foundation.h>
#import "OCClassSettings.h"
#import "OCIPNotificationCenter.h"
#import "OCLogToggle.h"
#import "OCLogTag.h"
#import "OCClassSettingsUserPreferences.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OCLogLevel)
{
	OCLogLevelVerbose = -1, //!< Log level for very verbose information, suitable for low-level debugging

	OCLogLevelDebug = 0,	//!< Log level for debug information
	OCLogLevelInfo,		//!< Info log level
	OCLogLevelWarning,	//!< Log level for warnings
	OCLogLevelError,	//!< Log level for errors

	OCLogLevelOff		//!< No logging
};

typedef NS_ENUM(NSInteger, OCLogFormat)
{
	OCLogFormatText, //!< Plain-text log format
	OCLogFormatJSON, //!< Log every message as one line of detailed JSON
	OCLogFormatJSONComposed //!< Log every message as one line of composed/simplified JSON
};

@class OCLogger;

typedef BOOL(^OCLogFilter)(OCLogger *logger, OCLogLevel logLevel, NSString * _Nullable functionName, NSString * _Nullable file, NSUInteger line, NSArray<OCLogTagName> * _Nullable * _Nullable pTags, NSString *_Nonnull * _Nonnull pLogMessage, uint64_t threadID, NSDate *timestamp); //!< Filter block. Returns YES if the message should be logged, NO otherwise. Can alter the log message via pLogMessage.

@class OCLogSource;
@class OCLogWriter;

@protocol OCLogPrivacyMasking <NSObject>
- (NSString *)privacyMaskedDescription;
@end

@protocol OCLogIntroFormat <NSObject>
- (NSString *)logIntroFormat; //!< Format of line to log at the beginning of logs. "{{stdIntro}}" gets replaced with the standard intro line. Omitting that tag will replace the standard intro line entirely.

@optional
- (nullable NSString *)logHostCommit; //!< Commit of the host process

@end

@interface OCLogger : NSObject <OCClassSettingsSupport, OCClassSettingsUserPreferencesSupport>
{
	BOOL _maskPrivateData;

	NSMutableArray<OCLogSource *> *_sources;

	NSMutableArray<OCLogWriter *> *_writers;
	dispatch_queue_t _writeQueue;

	NSMutableArray <OCLogToggle *> *_toggles;
	NSMutableDictionary<OCLogComponentIdentifier, OCLogToggle *> *_togglesByIdentifier;

	OCLogFilter _filter;
}

@property(assign,class) OCLogLevel logLevel;
@property(readonly,class) OCLogFormat logFormat;
@property(assign,class) BOOL maskPrivateData;
@property(readonly,class) BOOL synchronousLoggingEnabled;
@property(readonly,class) BOOL coloredLogging;

@property(copy,readonly,nonatomic) NSArray<OCLogWriter *> *writers;

@property(readonly,strong) NSArray<OCLogToggle *> *toggles;

@property(readonly,strong,nonatomic) dispatch_queue_t writeQueue;

@property(class,readonly,strong,nonatomic) OCLogger *sharedLogger;

#pragma mark - Conditions
+ (BOOL)logsForLevel:(OCLogLevel)level;

#pragma mark - Privacy masking
+ (nullable id)applyPrivacyMask:(nullable id)object;

#pragma mark - Logging
- (void)appendLogLevel:(OCLogLevel)logLevel force:(BOOL)force forceSyncWrite:(BOOL)forceSyncWrite functionName:(NSString *)functionName file:(NSString *)file line:(NSUInteger)line tags:(nullable NSArray<OCLogTagName> *)tags message:(NSString *)formatString arguments:(va_list)args NS_FORMAT_FUNCTION(8,0);
- (void)appendLogLevel:(OCLogLevel)logLevel force:(BOOL)force forceSyncWrite:(BOOL)forceSyncWrite functionName:(nullable NSString *)functionName file:(nullable NSString *)file line:(NSUInteger)line tags:(nullable NSArray<OCLogTagName> *)tags message:(NSString *)formatString, ... NS_FORMAT_FUNCTION(8,9);

- (void)appendLogLevel:(OCLogLevel)logLevel functionName:(nullable NSString *)functionName file:(nullable NSString *)file line:(NSUInteger)line tags:(nullable NSArray<OCLogTagName> *)tags message:(NSString *)formatString arguments:(va_list)args NS_FORMAT_FUNCTION(6,0);
- (void)appendLogLevel:(OCLogLevel)logLevel functionName:(nullable NSString *)functionName file:(nullable NSString *)file line:(NSUInteger)line tags:(nullable NSArray<OCLogTagName> *)tags message:(NSString *)formatString, ... NS_FORMAT_FUNCTION(6,7);

- (void)rawAppendLogLevel:(OCLogLevel)logLevel functionName:(NSString * _Nullable)functionName file:(NSString * _Nullable)file line:(NSUInteger)line tags:(nullable NSArray<OCLogTagName> *)tags logMessage:(NSString *)logMessage threadID:(uint64_t)threadID timestamp:(NSDate *)timestamp forceSyncWrite:(BOOL)forceSyncWrite;

#pragma mark - Sources
- (void)addSource:(OCLogSource *)logSource;
- (void)removeSource:(OCLogSource *)logSource;

#pragma mark - Filters
- (void)addFilter:(OCLogFilter)filter;

#pragma mark - Writers
- (void)addWriter:(OCLogWriter *)logWriter; //!< Adds a writer and opens it
- (nullable OCLogWriter *)writerWithIdentifier:(OCLogComponentIdentifier)identifier;
- (void)pauseWritersWithIntermittentBlock:(dispatch_block_t)intermittentBlock; //!< Pauses log writing: closes all writers, executes intermittentBlock, opens all writers, resumes logging

#pragma mark - Toggles
- (void)addToggle:(OCLogToggle *)logToggle; //!< Adds a toggle
- (BOOL)isToggleEnabled:(OCLogComponentIdentifier)toggleIdentifier; //!< Returns YES if the toggle is enabled, NO otherwise

#pragma mark - Log intro
- (NSString *)logIntro; //!< Introductory lines to start logging (and new log files) with. Allows for app-side injection of additions via OCLogger OCLogAdditionalIntro conformance.

@end

extern OCClassSettingsIdentifier OCClassSettingsIdentifierLog;

extern OCClassSettingsKey OCClassSettingsKeyLogLevel;
extern OCClassSettingsKey OCClassSettingsKeyLogPrivacyMask;
extern OCClassSettingsKey OCClassSettingsKeyLogEnabledComponents;
extern OCClassSettingsKey OCClassSettingsKeyLogSynchronousLogging;
extern OCClassSettingsKey OCClassSettingsKeyLogColored;
extern OCClassSettingsKey OCClassSettingsKeyLogOnlyTags;
extern OCClassSettingsKey OCClassSettingsKeyLogOmitTags;
extern OCClassSettingsKey OCClassSettingsKeyLogOnlyMatching;
extern OCClassSettingsKey OCClassSettingsKeyLogOmitMatching;
extern OCClassSettingsKey OCClassSettingsKeyLogBlankFilteredMessages;
extern OCClassSettingsKey OCClassSettingsKeyLogSingleLined;
extern OCClassSettingsKey OCClassSettingsKeyLogMaximumLogMessageSize;
extern OCClassSettingsKey OCClassSettingsKeyLogFormat;

extern OCIPCNotificationName OCIPCNotificationNameLogSettingsChanged;

@interface NSArray (OCLogTagMerge)
- (NSArray<NSString *> *)arrayByMergingTagsFromArray:(NSArray<NSString *> *)mergeTags;
@end

NS_ASSUME_NONNULL_END

#define OCLogGetTags(obj)		([obj conformsToProtocol:@protocol(OCLogTagging)] ? [(id<OCLogTagging>)obj logTags] : nil)

#define OCLogAddTags(obj,extraTags)	([obj conformsToProtocol:@protocol(OCLogTagging)] ? \
	((extraTags==nil) ? \
		[(id<OCLogTagging>)obj logTags] : \
		[[(id<OCLogTagging>)obj logTags] arrayByAddingObjectsFromArray:(id _Nonnull)(extraTags)] ) : \
	(extraTags))

#define OCLogMergeTags(obj,extraTags)	([obj conformsToProtocol:@protocol(OCLogTagging)] ? \
	((extraTags==nil) ? \
		[(id<OCLogTagging>)obj logTags] : \
		[[(id<OCLogTagging>)obj logTags] arrayByMergingTagsFromArray:(id _Nonnull)(extraTags)] ) : \
	(extraTags))

#define OCLogToggleEnabled(toggleID)	((toggleID!=nil) ? [OCLogger.sharedLogger isToggleEnabled:toggleID] : YES)

#define OCLoggingEnabled()		[OCLogger logsForLevel:OCLogLevelError]

// Convenience logging (with auto-tags)
#define _OC_LOG(obj,level,format,...)   if ([OCLogger logsForLevel:level])   {  [[OCLogger sharedLogger] appendLogLevel:level   functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:OCLogGetTags(obj) message:format, ##__VA_ARGS__]; }

#define OCLogVerbose(format,...)	_OC_LOG(self, OCLogLevelVerbose, format, ##__VA_ARGS__)
#define OCLogDebug(format,...)		_OC_LOG(self, OCLogLevelDebug,   format, ##__VA_ARGS__)
#define OCLog(format,...)   		_OC_LOG(self, OCLogLevelInfo,    format, ##__VA_ARGS__)
#define OCLogWarning(format,...)   	_OC_LOG(self, OCLogLevelWarning, format, ##__VA_ARGS__)
#define OCLogError(format,...)   	_OC_LOG(self, OCLogLevelError,   format, ##__VA_ARGS__)

#define OCWLogVerbose(format,...)	_OC_LOG(weakSelf, OCLogLevelVerbose, format, ##__VA_ARGS__)
#define OCWLogDebug(format,...)		_OC_LOG(weakSelf, OCLogLevelDebug,   format, ##__VA_ARGS__)
#define OCWLog(format,...)   		_OC_LOG(weakSelf, OCLogLevelInfo,    format, ##__VA_ARGS__)
#define OCWLogWarning(format,...)   	_OC_LOG(weakSelf, OCLogLevelWarning, format, ##__VA_ARGS__)
#define OCWLogError(format,...)   	_OC_LOG(weakSelf, OCLogLevelError,   format, ##__VA_ARGS__)

// Tagged logging (with auto-tags + extra-tags)
#define _OC_TLOG(obj,level,extraTags,format,...)	if ([OCLogger logsForLevel:level])   {  [[OCLogger sharedLogger] appendLogLevel:level functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:OCLogAddTags(obj,extraTags) message:format, ##__VA_ARGS__]; }

#define OCTLogVerbose(extraTags, format,...)	_OC_TLOG(self, OCLogLevelVerbose, extraTags, format, ##__VA_ARGS__)
#define OCTLogDebug(extraTags, format,...)	_OC_TLOG(self, OCLogLevelDebug,   extraTags, format, ##__VA_ARGS__)
#define OCTLog(extraTags, format,...)		_OC_TLOG(self, OCLogLevelInfo,    extraTags, format, ##__VA_ARGS__)
#define OCTLogWarning(extraTags, format,...)	_OC_TLOG(self, OCLogLevelWarning, extraTags, format, ##__VA_ARGS__)
#define OCTLogError(extraTags, format,...)	_OC_TLOG(self, OCLogLevelError,   extraTags, format, ##__VA_ARGS__)

// Tagged logging (with auto-tags + extra-tags + weakSelf)
#define OCWTLogVerbose(extraTags, format,...)	_OC_TLOG(weakSelf, OCLogLevelVerbose, extraTags, format, ##__VA_ARGS__)
#define OCWTLogDebug(extraTags, format,...)	_OC_TLOG(weakSelf, OCLogLevelDebug,   extraTags, format, ##__VA_ARGS__)
#define OCWTLog(extraTags, format,...)		_OC_TLOG(weakSelf, OCLogLevelInfo,    extraTags, format, ##__VA_ARGS__)
#define OCWTLogWarning(extraTags, format,...)	_OC_TLOG(weakSelf, OCLogLevelWarning, extraTags, format, ##__VA_ARGS__)
#define OCWTLogError(extraTags, format,...)	_OC_TLOG(weakSelf, OCLogLevelError,   extraTags, format, ##__VA_ARGS__)

// Parametrized logging (with toggles, auto-tags, extra-tags) - checking for log level OCLogLevelError if forced, to determine if logging is enabled (if it doesn't log for errors, logging is turned off)
#define _OC_PLOG(obj, level, forceLog, syncWrite, toggleID, extraTags, format,...)  if ([OCLogger logsForLevel:(forceLog ? OCLogLevelError : level)] && OCLogToggleEnabled(toggleID)) {  [[OCLogger sharedLogger] appendLogLevel:level force:forceLog forceSyncWrite:syncWrite functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:OCLogAddTags(obj,extraTags) message:format, ##__VA_ARGS__]; }

#define OCPLogVerbose(toggleID, extraTags, format,...)  _OC_PLOG(self, OCLogLevelVerbose, NO, NO, toggleID, extraTags, format, ##__VA_ARGS__)
#define OCPLogDebug(toggleID, extraTags, format,...)   	_OC_PLOG(self, OCLogLevelDebug,   NO, NO, toggleID, extraTags, format, ##__VA_ARGS__)
#define OCPLog(toggleID, extraTags, format,...)   	_OC_PLOG(self, OCLogLevelInfo,    NO, NO, toggleID, extraTags, format, ##__VA_ARGS__)
#define OCPLogWarning(toggleID, extraTags, format,...)  _OC_PLOG(self, OCLogLevelWarning, NO, NO, toggleID, extraTags, format, ##__VA_ARGS__)
#define OCPLogError(toggleID, extraTags, format,...)   	_OC_PLOG(self, OCLogLevelError,   NO, NO, toggleID, extraTags, format, ##__VA_ARGS__)

// Parametrized forced logging (with toggles, auto-tags, extra-tags)
#define OCPFLogVerbose(toggleID, extraTags, format,...)	_OC_PLOG(self, OCLogLevelVerbose, YES, NO, toggleID, extraTags, format, ##__VA_ARGS__)
#define OCPFLogDebug(toggleID, extraTags, format,...)	_OC_PLOG(self, OCLogLevelDebug,   YES, NO, toggleID, extraTags, format, ##__VA_ARGS__)
#define OCPFLog(toggleID, extraTags, format,...)	_OC_PLOG(self, OCLogLevelInfo,    YES, NO, toggleID, extraTags, format, ##__VA_ARGS__)
#define OCPFLogWarning(toggleID, extraTags, format,...) _OC_PLOG(self, OCLogLevelWarning, YES, NO, toggleID, extraTags, format, ##__VA_ARGS__)
#define OCPFLogError(toggleID, extraTags, format,...)	_OC_PLOG(self, OCLogLevelError,   YES, NO, toggleID, extraTags, format, ##__VA_ARGS__)

// Parametrized forced sync logging (with toggles, auto-tags, extra-tags)
#define OCPFSLogVerbose(toggleID, extraTags, format,...) _OC_PLOG(self, OCLogLevelVerbose, YES, YES, toggleID, extraTags, format, ##__VA_ARGS__)
#define OCPFSLogDebug(toggleID, extraTags, format,...)	 _OC_PLOG(self, OCLogLevelDebug,   YES, YES, toggleID, extraTags, format, ##__VA_ARGS__)
#define OCPFSLog(toggleID, extraTags, format,...)	 _OC_PLOG(self, OCLogLevelInfo,    YES, YES, toggleID, extraTags, format, ##__VA_ARGS__)
#define OCPFSLogWarning(toggleID, extraTags, format,...) _OC_PLOG(self, OCLogLevelWarning, YES, YES, toggleID, extraTags, format, ##__VA_ARGS__)
#define OCPFSLogError(toggleID, extraTags, format,...)	 _OC_PLOG(self, OCLogLevelError,   YES, YES, toggleID, extraTags, format, ##__VA_ARGS__)

// Parametrized forced logging (with toggles, auto-tags, merged extra-tags)
#define _OC_PMLOG(obj, level, forceLog, syncWrite, toggleID, extraTags, format,...)  if ([OCLogger logsForLevel:(forceLog ? OCLogLevelError : level)] && OCLogToggleEnabled(toggleID)) {  [[OCLogger sharedLogger] appendLogLevel:level force:forceLog forceSyncWrite:syncWrite functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:OCLogMergeTags(obj,extraTags) message:format, ##__VA_ARGS__]; }

#define OCPFMLogVerbose(toggleID, extraTags, format,...) _OC_PMLOG(self, OCLogLevelVerbose, YES, NO, toggleID, extraTags, format, ##__VA_ARGS__)
#define OCPFMLogDebug(toggleID, extraTags, format,...)	 _OC_PMLOG(self, OCLogLevelDebug,   YES, NO, toggleID, extraTags, format, ##__VA_ARGS__)
#define OCPFMLog(toggleID, extraTags, format,...)	 _OC_PMLOG(self, OCLogLevelInfo,    YES, NO, toggleID, extraTags, format, ##__VA_ARGS__)
#define OCPFMLogWarning(toggleID, extraTags, format,...) _OC_PMLOG(self, OCLogLevelWarning, YES, NO, toggleID, extraTags, format, ##__VA_ARGS__)
#define OCPFMLogError(toggleID, extraTags, format,...)	 _OC_PMLOG(self, OCLogLevelError,   YES, NO, toggleID, extraTags, format, ##__VA_ARGS__)

// Raw logging (with manual tags)
#define _OC_RLOG(level,tags,format,...)   	if ([OCLogger logsForLevel:level])   {  [[OCLogger sharedLogger] appendLogLevel:level functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:tags message:format, ##__VA_ARGS__]; }
#define OCRLogVerbose(tags,format,...)		_OC_RLOG(OCLogLevelVerbose, tags, format, ##__VA_ARGS__)
#define OCRLogDebug(tags,format,...)		_OC_RLOG(OCLogLevelDebug,   tags, format, ##__VA_ARGS__)
#define OCRLog(tags,format,...)			_OC_RLOG(OCLogLevelInfo,    tags, format, ##__VA_ARGS__)
#define OCRLogWarning(tags,format,...)		_OC_RLOG(OCLogLevelWarning, tags, format, ##__VA_ARGS__)
#define OCRLogError(tags,format,...)		_OC_RLOG(OCLogLevelError,   tags, format, ##__VA_ARGS__)

#define OCLogPrivate(obj) [OCLogger applyPrivacyMask:(obj)]
