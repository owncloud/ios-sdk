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

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OCLogLevel)
{
	OCLogLevelDebug,	//!< Verbose information
	OCLogLevelInfo,		//!< Info log level
	OCLogLevelWarning,	//!< Log level for warnings
	OCLogLevelError,	//!< Log level for errors

	OCLogLevelOff		//!< No logging
};

@class OCLogger;

typedef BOOL(^OCLogFilter)(OCLogger *logger, OCLogLevel logLevel, NSString * _Nullable functionName, NSString * _Nullable file, NSUInteger line, NSArray<OCLogTagName> ** _Nullable pTags, NSString **pLogMessage, uint64_t threadID, NSDate *timestamp); //!< Filter block. Returns YES if the message should be logged, NO otherwise. Can alter the log message via pLogMessage.

@class OCLogSource;
@class OCLogWriter;

@protocol OCLogPrivacyMasking <NSObject>
- (NSString *)privacyMaskedDescription;
@end

@interface OCLogger : NSObject <OCClassSettingsSupport>
{
	BOOL _maskPrivateData;

	NSMutableArray<OCLogSource *> *_sources;

	NSMutableArray<OCLogWriter *> *_writers;
	dispatch_queue_t _writerQueue;

	NSMutableArray <OCLogToggle *> *_toggles;
	NSMutableDictionary<OCLogComponentIdentifier, OCLogToggle *> *_togglesByIdentifier;

	OCLogFilter _filter;
}

@property(assign,class) OCLogLevel logLevel;
@property(assign,class) BOOL maskPrivateData;
@property(readonly,class) BOOL synchronousLoggingEnabled;

@property(copy,readonly,nonatomic) NSArray<OCLogWriter *> *writers;

@property(readonly,strong) NSArray<OCLogToggle *> *toggles;

@property(class,readonly,strong,nonatomic) OCLogger *sharedLogger;

#pragma mark - Privacy masking
+ (nullable id)applyPrivacyMask:(nullable id)object;

#pragma mark - Logging
- (void)appendLogLevel:(OCLogLevel)logLevel functionName:(nullable NSString *)functionName file:(nullable NSString *)file line:(NSUInteger)line tags:(nullable NSArray<OCLogTagName> *)tags message:(NSString *)formatString arguments:(va_list)args;
- (void)appendLogLevel:(OCLogLevel)logLevel functionName:(nullable NSString *)functionName file:(nullable NSString *)file line:(NSUInteger)line tags:(nullable NSArray<OCLogTagName> *)tags message:(NSString *)formatString, ...;

- (void)rawAppendLogLevel:(OCLogLevel)logLevel functionName:(NSString * _Nullable)functionName file:(NSString * _Nullable)file line:(NSUInteger)line tags:(nullable NSArray<OCLogTagName> *)tags logMessage:(NSString *)logMessage threadID:(uint64_t)threadID timestamp:(NSDate *)timestamp;

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

@end

extern OCClassSettingsIdentifier OCClassSettingsIdentifierLog;

extern OCClassSettingsKey OCClassSettingsKeyLogLevel;
extern OCClassSettingsKey OCClassSettingsKeyLogPrivacyMask;
extern OCClassSettingsKey OCClassSettingsKeyLogEnabledComponents;
extern OCClassSettingsKey OCClassSettingsKeyLogSynchronousLogging;
extern OCClassSettingsKey OCClassSettingsKeyLogOnlyTags;
extern OCClassSettingsKey OCClassSettingsKeyLogOmitTags;
extern OCClassSettingsKey OCClassSettingsKeyLogOnlyMatching;
extern OCClassSettingsKey OCClassSettingsKeyLogOmitMatching;
extern OCClassSettingsKey OCClassSettingsKeyLogBlankFilteredMessages;

extern OCIPCNotificationName OCIPCNotificationNameLogSettingsChanged;

NS_ASSUME_NONNULL_END

#define OCLogGetTags(obj)		([obj conformsToProtocol:@protocol(OCLogTagging)] ? [(id<OCLogTagging>)obj logTags] : nil)

#define OCLogAddTags(obj,extraTags)	([obj conformsToProtocol:@protocol(OCLogTagging)] ? \
	((extraTags==nil) ? \
		[(id<OCLogTagging>)obj logTags] : \
		[[(id<OCLogTagging>)obj logTags] arrayByAddingObjectsFromArray:(id _Nonnull)(extraTags)] ) : \
	(extraTags))

#define OCLogToggleEnabled(toggleID)		((toggleID!=nil) ? [OCLogger.sharedLogger isToggleEnabled:toggleID] : YES)

// Convenience logging (with auto-tags)
#define OCLogDebug(format,...)   		if (OCLogger.logLevel <= OCLogLevelDebug)   {  [[OCLogger sharedLogger] appendLogLevel:OCLogLevelDebug   functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:OCLogGetTags(self) message:format, ##__VA_ARGS__]; }
#define OCLog(format,...)   			if (OCLogger.logLevel <= OCLogLevelInfo)    {  [[OCLogger sharedLogger] appendLogLevel:OCLogLevelInfo    functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:OCLogGetTags(self) message:format, ##__VA_ARGS__]; }
#define OCLogWarning(format,...)   		if (OCLogger.logLevel <= OCLogLevelWarning) {  [[OCLogger sharedLogger] appendLogLevel:OCLogLevelWarning functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:OCLogGetTags(self) message:format, ##__VA_ARGS__]; }
#define OCLogError(format,...)   		if (OCLogger.logLevel <= OCLogLevelError)   {  [[OCLogger sharedLogger] appendLogLevel:OCLogLevelError   functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:OCLogGetTags(self) message:format, ##__VA_ARGS__]; }

// Tagged logging (with auto-tags + extra-tags)
#define OCTLogDebug(extraTags, format,...)   	if (OCLogger.logLevel <= OCLogLevelDebug)   {  [[OCLogger sharedLogger] appendLogLevel:OCLogLevelDebug   functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:OCLogAddTags(self,extraTags) message:format, ##__VA_ARGS__]; }
#define OCTLog(extraTags, format,...)   	if (OCLogger.logLevel <= OCLogLevelInfo)    {  [[OCLogger sharedLogger] appendLogLevel:OCLogLevelInfo    functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:OCLogAddTags(self,extraTags) message:format, ##__VA_ARGS__]; }
#define OCTLogWarning(extraTags, format,...)  if (OCLogger.logLevel <= OCLogLevelWarning) {  [[OCLogger sharedLogger] appendLogLevel:OCLogLevelWarning functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:OCLogAddTags(self,extraTags) message:format, ##__VA_ARGS__]; }
#define OCTLogError(extraTags, format,...)   	if (OCLogger.logLevel <= OCLogLevelError)   {  [[OCLogger sharedLogger] appendLogLevel:OCLogLevelError   functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:OCLogAddTags(self,extraTags) message:format, ##__VA_ARGS__]; }

// Tagged logging (with auto-tags + extra-tags + weakSelf)
#define OCWTLogDebug(extraTags, format,...)   	if (OCLogger.logLevel <= OCLogLevelDebug)   {  [[OCLogger sharedLogger] appendLogLevel:OCLogLevelDebug   functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:OCLogAddTags(weakSelf,extraTags) message:format, ##__VA_ARGS__]; }
#define OCWTLog(extraTags, format,...)   	if (OCLogger.logLevel <= OCLogLevelInfo)    {  [[OCLogger sharedLogger] appendLogLevel:OCLogLevelInfo    functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:OCLogAddTags(weakSelf,extraTags) message:format, ##__VA_ARGS__]; }
#define OCWTLogWarning(extraTags, format,...)  if (OCLogger.logLevel <= OCLogLevelWarning) {  [[OCLogger sharedLogger] appendLogLevel:OCLogLevelWarning functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:OCLogAddTags(weakSelf,extraTags) message:format, ##__VA_ARGS__]; }
#define OCWTLogError(extraTags, format,...)   	if (OCLogger.logLevel <= OCLogLevelError)   {  [[OCLogger sharedLogger] appendLogLevel:OCLogLevelError   functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:OCLogAddTags(weakSelf,extraTags) message:format, ##__VA_ARGS__]; }

// Parametrized logging (with toggles, auto-tags, extra-tags)
#define OCPLogDebug(toggleID, extraTags, format,...)   	if ((OCLogger.logLevel <= OCLogLevelDebug)   && OCLogToggleEnabled(toggleID)) {  [[OCLogger sharedLogger] appendLogLevel:OCLogLevelDebug   functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:OCLogAddTags(self,extraTags) message:format, ##__VA_ARGS__]; }
#define OCPLog(toggleID, extraTags, format,...)   	if ((OCLogger.logLevel <= OCLogLevelInfo)    && OCLogToggleEnabled(toggleID)) {  [[OCLogger sharedLogger] appendLogLevel:OCLogLevelInfo    functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:OCLogAddTags(self,extraTags) message:format, ##__VA_ARGS__]; }
#define OCPLogWarning(toggleID, extraTags, format,...)  if ((OCLogger.logLevel <= OCLogLevelWarning) && OCLogToggleEnabled(toggleID)) {  [[OCLogger sharedLogger] appendLogLevel:OCLogLevelWarning functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:OCLogAddTags(self,extraTags) message:format, ##__VA_ARGS__]; }
#define OCPLogError(toggleID, extraTags, format,...)   	if ((OCLogger.logLevel <= OCLogLevelError)   && OCLogToggleEnabled(toggleID)) {  [[OCLogger sharedLogger] appendLogLevel:OCLogLevelError   functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:OCLogAddTags(self,extraTags) message:format, ##__VA_ARGS__]; }

// Raw logging (with manual tags)
#define OCRLogDebug(tags,format,...)   		if (OCLogger.logLevel <= OCLogLevelDebug)   {  [[OCLogger sharedLogger] appendLogLevel:OCLogLevelDebug   functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:tags message:format, ##__VA_ARGS__]; }
#define OCRLog(tags,format,...)   		if (OCLogger.logLevel <= OCLogLevelInfo)    {  [[OCLogger sharedLogger] appendLogLevel:OCLogLevelInfo    functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:tags message:format, ##__VA_ARGS__]; }
#define OCRLogWarning(tags,format,...)   	if (OCLogger.logLevel <= OCLogLevelWarning) {  [[OCLogger sharedLogger] appendLogLevel:OCLogLevelWarning functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:tags message:format, ##__VA_ARGS__]; }
#define OCRLogError(tags,format,...)   		if (OCLogger.logLevel <= OCLogLevelError)   {  [[OCLogger sharedLogger] appendLogLevel:OCLogLevelError   functionName:@(__PRETTY_FUNCTION__) file:@(__FILE__) line:__LINE__ tags:tags message:format, ##__VA_ARGS__]; }

#define OCLogPrivate(obj) [OCLogger applyPrivacyMask:(obj)]
