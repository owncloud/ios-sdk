//
//  OCItem+OCFileURLMetadata.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 03.10.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCItem+OCFileURLMetadata.h"

#import <CoreServices/CoreServices.h>

@implementation OCItem (OCFileURLMetadata)

- (NSError *)updateMetadataFromFileURL:(NSURL *)fileURL
{
	NSNumber *filesize = nil;
	NSString *typeIdentifier = nil;
	NSDate *creationDate = nil,  *lastModified = nil;
	NSError *error = nil;

	[fileURL getResourceValue:&filesize forKey:NSURLFileSizeKey error:&error];
	[fileURL getResourceValue:&creationDate forKey:NSURLCreationDateKey error:&error];
	[fileURL getResourceValue:&lastModified forKey:NSURLContentModificationDateKey error:&error];
	[fileURL getResourceValue:&typeIdentifier forKey:NSURLTypeIdentifierKey error:&error];

	self.creationDate = creationDate;
	self.lastModified = lastModified;
	self.size = filesize.integerValue;

	if (typeIdentifier != nil)
	{
		self.mimeType = ((NSString *)CFBridgingRelease(UTTypeCopyPreferredTagWithClass((__bridge CFStringRef _Nonnull)(typeIdentifier), kUTTagClassMIMEType)));
	}

	return (error);
}

@end
