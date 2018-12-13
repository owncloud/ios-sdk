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

@interface OCLogFileWriter ()
{
	int _logFileFD;
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

- (nullable NSError *)eraseOrTruncate
{
	NSError *error = nil;

	if ([[NSFileManager defaultManager] fileExistsAtPath:self.logFileURL.path])
	{
		if (![[NSFileManager defaultManager] removeItemAtURL:self.logFileURL error:&error])
		{
			int truncateFD;

			if ((truncateFD = open((const char *)_logFileURL.path.UTF8String, O_WRONLY|O_TRUNC, S_IRUSR|S_IWUSR)) != -1)
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

@end

OCLogComponentIdentifier OCLogComponentIdentifierWriterFile = @"writer.file";
