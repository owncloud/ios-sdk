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

static OCLogLevel sOCLogLevel;
static BOOL sOCLogMaskPrivateData;

@implementation OCLogger

+ (instancetype)sharedLogger
{
	static dispatch_once_t onceToken;
	static OCLogger *sharedLogger;

	dispatch_once(&onceToken, ^{
		sharedLogger = [OCLogger new];
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
		NSString *sourceLocationAndPrivacyStatus = [NSString stringWithFormat:@"%@:%lu|%@", [file lastPathComponent], (unsigned long)line, (sOCLogMaskPrivateData ? @"MASKED" : @"FULL")];
		logMessage = [[NSString alloc] initWithFormat:formatString arguments:args];

		NSLog(@"%@ [%@]", logMessage, sourceLocationAndPrivacyStatus);
	}
}

- (id)applyPrivacyMask:(id)object
{
	if (sOCLogMaskPrivateData)
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

@end
