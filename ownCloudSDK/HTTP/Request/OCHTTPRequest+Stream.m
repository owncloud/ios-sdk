//
//  OCHTTPRequest+Stream.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 31.07.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCHTTPRequest+Stream.h"
#import "OCHTTPPipelineTask.h"

@implementation OCHTTPRequest (Stream)

+ (OCRunLoopThread *)sharedStreamThread
{
	static dispatch_once_t onceToken;
	static OCRunLoopThread *sharedStreamThread;

	dispatch_once(&onceToken, ^{
		sharedStreamThread = [OCRunLoopThread runLoopThreadNamed:@"OCHTTP Shared Stream Thread"];
	});

	return (sharedStreamThread);
}

- (BOOL)shouldStreamResponse
{
	return (self.ephermalStreamHandler != nil);
}

- (void)handleResponseStreamData:(NSData *)data forPipelineTask:(OCHTTPPipelineTask *)pipelineTask
{
	NSOutputStream *outStream = nil;

	@synchronized(self)
	{
		// Create input/output stream pair if none exists
		if ((outStream = _streamingResponseBodyOutputStream) == nil)
		{
			OCHTTPRequestEphermalStreamHandler ephermalStreamHandler = self.ephermalStreamHandler;

			if (ephermalStreamHandler != nil)
			{
				NSInputStream *inStream;

				// Create stream pair with shared buffer
				const NSUInteger sharedBufferSize = 8192;
				[NSStream getBoundStreamsWithBufferSize:sharedBufferSize inputStream:&inStream outputStream:&outStream];

				_streamingResponseBodyInputStream = inStream;
				_streamingResponseBodyOutputStream = outStream;

				// Schedule outStream on shared stream thread
				[OCHTTPRequest.sharedStreamThread dispatchBlockToRunLoopAsync:^{
					[outStream scheduleInRunLoop:NSRunLoop.currentRunLoop forMode:NSDefaultRunLoopMode];
					[outStream open];

					ephermalStreamHandler(self, pipelineTask.response, inStream, nil);
				}];
			}
		}
	}

	// Write data to outStream on shared stream thread
	[OCHTTPRequest.sharedStreamThread dispatchBlockToRunLoopAsync:^{
		@autoreleasepool {
			uint8_t *p_data = (uint8_t *)data.bytes;
			NSUInteger remainingBytes = data.length;

			while (remainingBytes > 0)
			{
				NSInteger writtenBytes = [outStream write:p_data maxLength:remainingBytes];

				if (writtenBytes >= 0)
				{
					remainingBytes -= writtenBytes;
					p_data += writtenBytes;
				}
				else
				{
					OCLogError(@"Error writing stream: %@", outStream.streamError);
				}
			}
		}
	}];
}

- (void)closeResponseStreamWithError:(NSError *)error forPipelineTask:(OCHTTPPipelineTask *)pipelineTask
{
	NSOutputStream *outStream = nil;

	if ((outStream = _streamingResponseBodyOutputStream) != nil)
	{
		// Close outStream on shared stream thread
		[OCHTTPRequest.sharedStreamThread dispatchBlockToRunLoopAsync:^{
			[outStream close];
		}];
	}

	OCHTTPRequestEphermalStreamHandler ephermalStreamHandler;

	if ((ephermalStreamHandler = self.ephermalStreamHandler) != nil)
	{
		// Signal end of stream (and any stream error) to stream handler on shared stream thread
		[OCHTTPRequest.sharedStreamThread dispatchBlockToRunLoopAsync:^{
			ephermalStreamHandler(self, pipelineTask.response, nil, nil);
		}];
	}
}

@end
