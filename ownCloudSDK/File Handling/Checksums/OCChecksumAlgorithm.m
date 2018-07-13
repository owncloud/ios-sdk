//
//  OCChecksumAlgorithm.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 21.06.18.
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

#import "OCChecksumAlgorithm.h"
#import "NSError+OCError.h"

@implementation OCChecksumAlgorithm

#pragma mark - Registration and lookup
+ (NSMutableDictionary <OCChecksumAlgorithmIdentifier, Class> *)_algorithmsByIdentifier
{
	static dispatch_once_t onceToken;
	static NSMutableDictionary *algorithmsByIdentifier;
	dispatch_once(&onceToken, ^{
		algorithmsByIdentifier = [NSMutableDictionary new];
	});

	return (algorithmsByIdentifier);
}

+ (OCChecksumAlgorithm *)algorithmForIdentifier:(OCChecksumAlgorithmIdentifier)identifier
{
	Class algorithmClass = Nil;

	if (identifier != nil)
	{
		@synchronized(self)
		{
			algorithmClass = [[self _algorithmsByIdentifier] objectForKey:identifier];
		}
	}

	return ([algorithmClass new]);
}

+ (dispatch_queue_t)computationQueue
{
	static dispatch_once_t onceToken;
	static dispatch_queue_t computationQueue = NULL;

	dispatch_once(&onceToken, ^{
		computationQueue = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0);
	});

	return(computationQueue);
}

+ (void)registerAlgorithmClass:(Class)algorithmClass
{
	OCChecksumAlgorithmIdentifier algorithmID;

	if ((algorithmID = [algorithmClass identifier]) != nil)
	{
		@synchronized(self)
		{
			[self _algorithmsByIdentifier][algorithmID] = algorithmClass;
		}
	}
}

#pragma mark - Algorithm interface
+ (OCChecksumAlgorithmIdentifier)identifier
{
	return(nil);
}

- (void)computeChecksumForFileAtURL:(NSURL *)fileURL completionHandler:(OCChecksumComputationCompletionHandler)completionHandler
{
	if (completionHandler == nil) { return; }

	if (fileURL == nil)
	{
		completionHandler(OCError(OCErrorInsufficientParameters), nil);
		return;
	}

	dispatch_async([OCChecksumAlgorithm computationQueue], ^{
		NSInputStream *inputStream;
		NSError *error = nil;
		OCChecksum *checksum = nil;

		if ((inputStream = [NSInputStream inputStreamWithURL:fileURL]) != nil)
		{
			do {
				if (inputStream.streamError != nil) { break; }

				[inputStream open];

				if (inputStream.streamError != nil) { break; }

				checksum = [self computeChecksumForInputStream:inputStream error:&error];
			} while(NO);

			if (inputStream.streamStatus != NSStreamStatusClosed)
			{
				[inputStream close];
			}

			if ((error==nil) && (inputStream.streamError != nil))
			{
				error = inputStream.streamError;
			}
		}

		completionHandler(error, checksum);
	});
}

- (void)verifyChecksum:(OCChecksum *)checksum forFileAtURL:(NSURL *)fileURL completionHandler:(OCChecksumVerificationCompletionHandler)completionHandler
{
	if (completionHandler == nil) { return; }

	if (checksum == nil)
	{
		completionHandler(OCError(OCErrorInsufficientParameters), NO, nil);
		return;
	}

	if (fileURL == nil)
	{
		completionHandler(OCError(OCErrorInsufficientParameters), NO, nil);
		return;
	}

	[self computeChecksumForFileAtURL:fileURL completionHandler:^(NSError *error, OCChecksum *computedChecksum) {
		completionHandler(error, [computedChecksum isEqual:checksum], computedChecksum);
	}];
}

#pragma mark - Algorithm implementation
- (OCChecksum *)computeChecksumForInputStream:(NSInputStream *)inputStream error:(NSError **)error
{
	if (error != NULL)
	{
		*error = OCError(OCErrorFeatureNotImplemented);
	}

	return (nil);
}

@end
