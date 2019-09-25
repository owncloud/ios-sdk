//
//  OCLogWriter.m
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

#import "OCLogWriter.h"
#import "OCAppIdentity.h"
#import "OCMacros.h"

@implementation OCLogWriter

static NSString *processName;
static NSDateFormatter *dateFormatter;

@synthesize isOpen = _isOpen;
@synthesize writeHandler = _writeHandler;
@synthesize rotationInterval = _rotationInterval;

+ (void)initialize {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		processName = [NSProcessInfo processInfo].processName;

		dateFormatter = [NSDateFormatter new];
		dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSSSSSZZZ";
	});
}

- (instancetype)initWithWriteHandler:(OCLogWriteHandler)writeHandler
{
	if ((self = [super initWithIdentifier:OCLogComponentIdentifierWriterStandardError]) != nil)
	{
		self.writeHandler = writeHandler;
	}

	return (self);
}

- (NSString *)name
{
	return (OCLocalized(@"Standard error output"));
}

- (NSError *)open
{
	_isOpen = YES;
	return (nil);
}

- (NSError *)close
{
	_isOpen = NO;
	return (nil);
}

+ (NSString*)timestampStringFrom:(NSDate*)date
{
	return [dateFormatter stringFromDate:date];
}

- (void)appendMessageWithLogLevel:(OCLogLevel)logLevel date:(NSDate *)date threadID:(uint64_t)threadID isMainThread:(BOOL)isMainThread privacyMasked:(BOOL)privacyMasked functionName:(NSString *)functionName file:(NSString *)file line:(NSUInteger)line tags:(nullable NSArray<OCLogTagName> *)tags message:(NSString *)message
{
	NSString *logLevelName = nil, *timestampString = nil, *leadingTags = nil, *trailingTags = nil;

	switch (logLevel)
	{
		case OCLogLevelDebug:
			logLevelName = OCLogger.coloredLogging ? @"⚪️" : @"[dbug]";
		break;

		case OCLogLevelInfo:
			logLevelName = OCLogger.coloredLogging ? @"🔵" : @"[info]";
		break;

		case OCLogLevelWarning:
			logLevelName = OCLogger.coloredLogging ? @"⚠️" : @"[WARN]";
		break;

		case OCLogLevelError:
			logLevelName = OCLogger.coloredLogging ? @"🛑" : @"[ERRO]";
		break;

		case OCLogLevelOff:
			return;
		break;
	}

	if ((tags != nil) && (tags.count > 0))
	{
		if (tags.count < 3)
		{
			leadingTags = [[NSString alloc] initWithFormat:@"[%@] ", [tags componentsJoinedByString:@", "]];
			trailingTags = @"";
		}
		else
		{
			leadingTags = [[NSString alloc] initWithFormat:@"[%@, …] ", [[tags subarrayWithRange:NSMakeRange(0, 2)] componentsJoinedByString:@", "]];
			trailingTags = [[NSString alloc] initWithFormat:@" [… %@]", [[tags subarrayWithRange:NSMakeRange(2, tags.count-2)] componentsJoinedByString:@", "]];
		}
	}
	else
	{
		leadingTags = @"";
		trailingTags = @"";
	}

	timestampString = [dateFormatter stringFromDate:date];

	[self appendMessage:[[NSString alloc] initWithFormat:@"%@ %@[%d%@%06llu] %@ | %@%@%@ [%@:%lu|%@]\n", timestampString, processName, getpid(), (isMainThread ? @"." : @":"), threadID, logLevelName, leadingTags, message, trailingTags, [file lastPathComponent], (unsigned long)line, (privacyMasked ? @"MASKED" : @"FULL")]];
}

- (void)appendMessage:(NSString *)message
{
	if (_writeHandler != nil)
	{
		_writeHandler(message);
	}
}

@end

OCLogComponentIdentifier OCLogComponentIdentifierWriterStandardError = @"writer.stderr";
