//
//  OCLogger.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

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
		NSString *logMessage;
		NSString *sourceLocationAndPrivacyStatus = [NSString stringWithFormat:@"%@:%lu|%@", [file lastPathComponent], (unsigned long)line, (sOCLogMaskPrivateData ? @"MASKED" : @"FULL")];
		va_list args;
		
		va_start(args, formatString);
		logMessage = [[NSString alloc] initWithFormat:formatString arguments:args];
		va_end(args);
		
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
