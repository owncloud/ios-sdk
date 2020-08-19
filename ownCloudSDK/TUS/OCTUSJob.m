//
//  OCTUSJob.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 29.04.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCTUSJob.h"
#import "OCChecksum.h"
#import "OCLogger.h"

@interface OCTUSJob () <NSFileManagerDelegate>
{
	OCTUSJobSegment *_lastSegment;
}
@end

@implementation OCTUSJob

- (instancetype)initWithHeader:(OCTUSHeader *)header segmentFolderURL:(NSURL *)segmentFolder fileURL:(NSURL *)fileURL creationURL:(NSURL *)creationURL
{
	if ((self = [super init]) != nil)
	{
		_header = header;
		_creationURL = creationURL;

		_maxSegmentSize = _header.maximumChunkSize.unsignedIntegerValue;

		_segmentFolderURL = segmentFolder;
		_fileURL = fileURL;
	}

	return (self);
}

#pragma mark - Segmentation
- (nullable OCTUSJobSegment *)requestSegmentFromOffset:(NSUInteger)offset withSize:(NSUInteger)size error:(NSError * _Nullable * _Nullable)outError
{
	if ((_lastSegment != nil) && (_lastSegment.offset == offset) && (_lastSegment.size == size) && _lastSegment.isValid)
	{
		return (_lastSegment);
	}
	else
	{
		if (_lastSegment.isValid)
		{
			[NSFileManager.defaultManager removeItemAtURL:_lastSegment.url error:NULL];
			_lastSegment = nil;
		}

		if (_fileURL != nil)
		{
			NSError *error = nil;
			NSURL *segmentFileURL = [_segmentFolderURL URLByAppendingPathComponent:NSUUID.UUID.UUIDString];
			NSFileHandle *srcFile = nil;
			NSFileHandle *dstFile = nil;
			NSUInteger copyChunkSize = 100000;
			NSUInteger bytesCopied = 0;
			BOOL copySuccessful = NO;

			do
			{
				if ((srcFile = [NSFileHandle fileHandleForReadingFromURL:_fileURL error:&error]) == nil)
				{
					OCLogError(@"Error opening file %@ for reading: %@", _fileURL, error);
					break;
				}

				if (![NSFileManager.defaultManager createFileAtPath:segmentFileURL.path contents:nil attributes:nil])
				{
					OCLogError(@"Error creating segment file %@", segmentFileURL);
					break;
				}

				if ((dstFile = [NSFileHandle fileHandleForWritingToURL:segmentFileURL error:&error]) == nil)
				{
					OCLogError(@"Error opening segment file %@ for writing: %@", segmentFileURL, error);
					break;
				}

				if (@available(iOS 13, *))
				{
					if (![srcFile seekToOffset:offset error:&error])
					{
						OCLogError(@"Error seeking to position %lu in file %@: %@", (unsigned long)offset, _fileURL, error);
						break;
					}

					while ((bytesCopied < size) && (copyChunkSize > 0)) {
						@autoreleasepool {
							NSData *data = nil;

							if (copyChunkSize > (size - bytesCopied))
							{
								copyChunkSize = (size - bytesCopied);
							}

							data = [srcFile readDataUpToLength:copyChunkSize error:&error];

							if (error != nil)
							{
								OCLogError(@"Error reading %lu bytes from %lu in file %@: %@", (unsigned long)size, (unsigned long)offset, _fileURL, error);
								break;
							}

							if (data != nil)
							{
								if (![dstFile writeData:data error:&error])
								{
									OCLogError(@"Error writiung %lu bytes to file %@: %@", (unsigned long)data.length, _fileURL, error);
									break;
								}
							}

							bytesCopied += data.length;

							if ((data.length == 0) || (error != nil)) { break; }
						}
					};

					if (error != nil) { break; }
				}
				else
				{
					@try
					{
						[srcFile seekToFileOffset:offset];

						while ((bytesCopied < size) && (copyChunkSize > 0)) {
							@autoreleasepool {
								NSData *data = nil;

								if (copyChunkSize > (size - bytesCopied))
								{
									copyChunkSize = (size - bytesCopied);
								}

								if ((data = [srcFile readDataOfLength:copyChunkSize]) != nil)
								{
									[dstFile writeData:data];

									bytesCopied += data.length;
								}

								if ((data.length == 0) || (error != nil)) { break; }
							}
						};
					}
					@catch(NSException *exception)
					{
						OCLogError(@"Exception copying %lu bytes from %@ to %@: %@", (unsigned long)size, _fileURL, segmentFileURL, OCLogPrivate(exception));
						break;
					}
				}

				copySuccessful = YES;
			}while(false);

			if (@available(iOS 13, *))
			{
				[srcFile closeAndReturnError:&error];
				[dstFile closeAndReturnError:&error];
			}
			else
			{
				@try
				{
					[srcFile closeFile];
					[dstFile closeFile];
				}
				@catch(NSException *exception)
				{
					OCLogError(@"Exception closing %@ + %@: %@", _fileURL, segmentFileURL, OCLogPrivate(exception));
				}
			}

			srcFile = nil;
			dstFile = nil;

			if (copySuccessful)
			{
				OCTUSJobSegment *segment = [OCTUSJobSegment new];

				segment.offset = offset;
				segment.size = bytesCopied;

				segment.url = segmentFileURL;

				_lastSegment = segment;

				return (segment);
			}
			else
			{
				if (outError != NULL)
				{
					*outError = error;
				}
			}
		}
	}

	return (nil);
}

#pragma mark - Destroy
- (void)destroy
{
	if (_segmentFolderURL != nil)
	{
		NSError *error = nil;

		NSFileManager *fileManager = [NSFileManager new];
		fileManager.delegate = self;

		if (![NSFileManager.defaultManager removeItemAtURL:_segmentFolderURL error:&error])
		{
			OCLogError(@"Error destroying OCTUSJob segmentFolder at %@: %@", _segmentFolderURL, error);
		}

		_segmentFolderURL = nil;
	}
}

- (BOOL)fileManager:(NSFileManager *)fileManager shouldRemoveItemAtURL:(NSURL *)URL
{
	return (YES);
}

#pragma mark - NSSecureCoding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if ((self = [super init]) != nil)
	{
		_header = [coder decodeObjectOfClass:OCTUSHeader.class forKey:@"header"];

		_fileURL = [coder decodeObjectOfClass:NSURL.class forKey:@"fileURL"];
		_segmentFolderURL = [coder decodeObjectOfClass:NSURL.class forKey:@"segmentFolderURL"];

		_uploadOffset = [coder decodeObjectOfClass:NSNumber.class forKey:@"uploadOffset"];

		_maxSegmentSize = [coder decodeInt64ForKey:@"maxSegmentSize"];

		_creationURL = [coder decodeObjectOfClass:NSURL.class forKey:@"creationURL"];
		_uploadURL = [coder decodeObjectOfClass:NSURL.class forKey:@"uploadURL"];

		_futureItemPath = [coder decodeObjectOfClass:NSString.class forKey:@"futureItemPath"];

		_fileName = [coder decodeObjectOfClass:NSString.class forKey:@"fileName"];
		_fileSize = [coder decodeObjectOfClass:NSNumber.class forKey:@"fileSize"];
		_fileModDate = [coder decodeObjectOfClass:NSDate.class forKey:@"fileModDate"];
		_fileChecksum = [coder decodeObjectOfClass:OCChecksum.class forKey:@"fileChecksum"];

		_eventTarget = [coder decodeObjectOfClass:OCEventTarget.class forKey:@"eventTarget"];

		_lastSegment = [coder decodeObjectOfClass:OCTUSJobSegment.class forKey:@"lastSegment"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_header forKey:@"header"];

	[coder encodeObject:_fileURL forKey:@"fileURL"];
	[coder encodeObject:_segmentFolderURL forKey:@"segmentFolderURL"];

	[coder encodeObject:_uploadOffset forKey:@"uploadOffset"];

	[coder encodeInt64:_maxSegmentSize forKey:@"maxSegmentSize"];

	[coder encodeObject:_creationURL forKey:@"creationURL"];
	[coder encodeObject:_uploadURL forKey:@"uploadURL"];

	[coder encodeObject:_futureItemPath forKey:@"futureItemPath"];

	[coder encodeObject:_fileName forKey:@"fileName"];
	[coder encodeObject:_fileSize forKey:@"fileSize"];
	[coder encodeObject:_fileModDate forKey:@"fileModDate"];
	[coder encodeObject:_fileChecksum forKey:@"fileChecksum"];

	[coder encodeObject:_eventTarget forKey:@"eventTarget"];

	[coder encodeObject:_lastSegment forKey:@"lastSegment"];
}

@end

@implementation OCTUSJobSegment

+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if ((self = [super init]) != nil)
	{
		_url = [coder decodeObjectOfClass:NSURL.class forKey:@"url"];
		_offset = [coder decodeInt64ForKey:@"offset"];
		_size = [coder decodeInt64ForKey:@"size"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_url forKey:@"url"];
	[coder encodeInt64:_offset forKey:@"offset"];
	[coder encodeInt64:_size forKey:@"size"];
}

- (BOOL)isValid
{
	return ((_url != nil) && (_size > 0) && [NSFileManager.defaultManager fileExistsAtPath:_url.path]);
}

@end
