//
//  OCTUSHeader.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.04.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

#import "OCTUSHeader.h"

@implementation OCTUSHeader

- (instancetype)initWithHTTPHeaderFields:(OCHTTPHeaderFields)headerFields
{
	if ((self = [super init]) != nil)
	{
		[self _populateFromHTTPHeaders:headerFields];
	}

	return (self);
}

- (void)_populateFromHTTPHeaders:(OCHTTPHeaderFields)headerFields
{
	NSString *tusVersion, *tusResumable, *tusExtensions, *tusMaxSize, *uploadOffset, *uploadLength;

	if ((tusVersion = headerFields[@"Tus-Version"]) != nil)
	{
		_versions = [tusVersion componentsSeparatedByString:@","];
	}

	if ((tusResumable = headerFields[@"Tus-Resumable"]) != nil)
	{
		_version = tusResumable;
		if (_versions == nil)
		{
			_versions = @[ _version ];
		}
	}

	if ((tusExtensions = headerFields[@"Tus-Extension"]) != nil)
	{
		_extensions = [tusExtensions componentsSeparatedByString:@","];
	}

	if ((tusMaxSize = headerFields[@"Tus-Max-Size"]) != nil)
	{
		_maximumSize = @(tusMaxSize.longLongValue);
	}

	if ((uploadOffset = headerFields[@"Upload-Offset"]) != nil)
	{
		_uploadOffset = @(uploadOffset.longLongValue);
	}

	if ((uploadLength = headerFields[@"Upload-Length"]) != nil)
	{
		_uploadLength = @(uploadLength.longLongValue);
	}
}

- (OCTUSSupport)supportFlags
{
	OCTUSSupport support = OCTUSSupportNone;

	if (_versions.count > 0)
	{
		support = OCTUSSupportAvailable;

		if ([_extensions containsObject:@"creation"]) { support |= OCTUSSupportExtensionCreation; }
		if ([_extensions containsObject:@"creation-with-upload"]) { support |= OCTUSSupportExtensionCreationWithUpload; }
		if ([_extensions containsObject:@"expiration"]) { support |= OCTUSSupportExtensionExpiration; }
	}

	return (support);
}

- (OCTUSInfo)info
{
	OCTUSInfo info = 0;

	OCTUSInfoSetSupport(info, self.supportFlags);
	OCTUSInfoSetMaximumSize(info, self.maximumSize.unsignedLongLongValue);

	return (info);
}

@end
