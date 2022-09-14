//
//  OCItem+OCFileURLMetadata.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 03.10.18.
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
