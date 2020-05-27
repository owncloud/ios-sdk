//
//  OCTUSHeader.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.04.20.
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

#import "OCTUSHeader.h"

@interface OCTUSHeader ()
{
	OCTUSMetadata _uploadMetadata;
	OCTUSMetadataString _uploadMetadataString;
}
@end

@implementation OCTUSHeader

@dynamic httpHeaderFields;

@dynamic supportFlags;
@dynamic info;

- (instancetype)initWithHTTPHeaderFields:(OCHTTPStaticHeaderFields)headerFields
{
	if ((self = [super init]) != nil)
	{
		[self _populateFromHTTPHeaders:headerFields];
	}

	return (self);
}

- (instancetype)initWithTUSInfo:(OCTUSInfo)info
{
	if ((self = [super init]) != nil)
	{
		[self _populateFromTusSupport:OCTUSInfoGetSupport(info)];

		UInt64 maxSize = OCTUSInfoGetMaximumSize(info);

		if (maxSize != 0)
		{
			_maximumSize = @(maxSize);
		}
	}

	return (self);
}

- (void)_populateFromTusSupport:(OCTUSSupport)support
{
	NSString *extensions[5];
	NSUInteger extensionCount = 0;

	#define ExpandFlag(flag,extension) \
		if (OCTUSIsSupported(support, flag)) \
		{ \
			extensions[extensionCount] = extension; \
			extensionCount++; \
		}

	ExpandFlag(OCTUSSupportExtensionCreation, 		OCTUSExtensionCreation)
	ExpandFlag(OCTUSSupportExtensionCreationWithUpload, 	OCTUSExtensionCreationWithUpload)
	ExpandFlag(OCTUSSupportExtensionExpiration, 		OCTUSExtensionExpiration)

	if (extensionCount > 0)
	{
		_extensions = [[NSArray alloc] initWithObjects:extensions count:extensionCount];
	}
}

- (void)_populateFromHTTPHeaders:(OCHTTPStaticHeaderFields)headerFields
{
	NSString *tusVersion, *tusResumable, *tusExtensions, *tusMaxSize, *uploadOffset, *uploadLength;

	if ((tusVersion = headerFields[OCTUSHeaderNameTusVersion]) != nil)
	{
		_versions = [tusVersion componentsSeparatedByString:@","];
	}

	if ((tusResumable = headerFields[OCTUSHeaderNameTusResumable]) != nil)
	{
		_version = tusResumable;
		if (_versions == nil)
		{
			_versions = @[ _version ];
		}
	}

	if ((tusExtensions = headerFields[OCTUSHeaderNameTusExtension]) != nil)
	{
		_extensions = [tusExtensions componentsSeparatedByString:@","];
	}

	if ((tusMaxSize = headerFields[OCTUSHeaderNameTusMaxSize]) != nil)
	{
		_maximumSize = @(tusMaxSize.longLongValue);
	}

	if ((uploadOffset = headerFields[OCTUSHeaderNameUploadOffset]) != nil)
	{
		_uploadOffset = @(uploadOffset.longLongValue);
	}

	if ((uploadLength = headerFields[OCTUSHeaderNameUploadLength]) != nil)
	{
		_uploadLength = @(uploadLength.longLongValue);
	}
}

- (OCTUSMetadata)uploadMetadata
{
	if ((_uploadMetadata == nil) && (_uploadMetadataString != nil))
	{
		_uploadMetadata = _uploadMetadataString.tusMetadata;
	}

	return (_uploadMetadata);
}

- (void)setUploadMetadata:(OCTUSMetadata)uploadMetaData
{
	_uploadMetadataString = nil;
	_uploadMetadata = uploadMetaData;
}

- (OCTUSMetadataString)uploadMetadataString
{
	if ((_uploadMetadataString == nil) && (_uploadMetadata != nil))
	{
		_uploadMetadataString = [NSString stringFromTUSMetadata:_uploadMetadata];
	}

	return (_uploadMetadataString);
}

- (void)setUploadMetadataString:(OCTUSMetadataString)uploadMetaDataString
{
	_uploadMetadata = nil;
	_uploadMetadataString = uploadMetaDataString;
}

- (OCHTTPHeaderFields)httpHeaderFields
{
	OCHTTPHeaderFields headerFields = [NSMutableDictionary new];

	if (_version != nil)
	{
		headerFields[OCTUSHeaderNameTusResumable] = _version;
	}

	if (_versions != nil)
	{
		headerFields[OCTUSHeaderNameTusVersion] = [_versions componentsJoinedByString:@","];
	}

	if (_extensions != nil)
	{
		headerFields[OCTUSHeaderNameTusExtension] = [_extensions componentsJoinedByString:@","];
	}

	if (_maximumSize != nil)
	{
		headerFields[OCTUSHeaderNameTusMaxSize] = _maximumSize.stringValue;
	}

	if (_uploadOffset != nil)
	{
		headerFields[OCTUSHeaderNameUploadOffset] = _uploadOffset.stringValue;
	}

	if (_uploadLength != nil)
	{
		headerFields[OCTUSHeaderNameUploadLength] = _uploadLength.stringValue;
	}

	if ((_uploadMetadata!=nil) || (_uploadMetadataString != nil))
	{
		headerFields[OCTUSHeaderNameUploadMetadata] = self.uploadMetadataString;
	}

	return ((headerFields.count > 0) ? headerFields : nil);
}

- (OCTUSSupport)supportFlags
{
	OCTUSSupport support = OCTUSSupportNone;

	if ((_versions.count > 0) || (_extensions.count > 0))
	{
		support = OCTUSSupportAvailable;

		if ([_extensions containsObject:OCTUSExtensionCreation])		{ support |= OCTUSSupportExtensionCreation; }
		if ([_extensions containsObject:OCTUSExtensionCreationWithUpload]) 	{ support |= OCTUSSupportExtensionCreationWithUpload; }
		if ([_extensions containsObject:OCTUSExtensionExpiration]) 		{ support |= OCTUSSupportExtensionExpiration; }
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

#pragma mark - NSSecureCoding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if ((self = [super init]) != nil)
	{
		NSSet *allowedClasses = [[NSSet alloc] initWithObjects:NSString.class, NSArray.class, nil];

		_version = [coder decodeObjectOfClass:NSString.class forKey:@"version"];

		_versions = [coder decodeObjectOfClasses:allowedClasses forKey:@"versions"];
		_extensions = [coder decodeObjectOfClasses:allowedClasses forKey:@"extensions"];

		_maximumSize = [coder decodeObjectOfClass:NSNumber.class forKey:@"maximumSize"];
		_maximumChunkSize = [coder decodeObjectOfClass:NSNumber.class forKey:@"maximumChunkSize"];
		_uploadOffset = [coder decodeObjectOfClass:NSNumber.class forKey:@"uploadOffset"];
		_uploadLength = [coder decodeObjectOfClass:NSNumber.class forKey:@"uploadLength"];

		_uploadMetadataString = [coder decodeObjectOfClass:NSString.class forKey:@"uploadMetadata"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_version forKey:@"version"];

	[coder encodeObject:_versions forKey:@"versions"];
	[coder encodeObject:_extensions forKey:@"extensions"];

	[coder encodeObject:_maximumSize forKey:@"maximumSize"];
	[coder encodeObject:_maximumChunkSize forKey:@"maximumChunkSize"];
	[coder encodeObject:_uploadOffset forKey:@"uploadOffset"];
	[coder encodeObject:_uploadLength forKey:@"uploadLength"];

	[coder encodeObject:self.uploadMetadataString forKey:@"uploadMetadata"];
}

@end

const OCTUSHeaderName OCTUSHeaderNameTusVersion = @"Tus-Version";
const OCTUSHeaderName OCTUSHeaderNameTusResumable = @"Tus-Resumable";
const OCTUSHeaderName OCTUSHeaderNameTusExtension = @"Tus-Extension";
const OCTUSHeaderName OCTUSHeaderNameTusMaxSize = @"Tus-Max-Size";
const OCTUSHeaderName OCTUSHeaderNameUploadOffset = @"Upload-Offset";
const OCTUSHeaderName OCTUSHeaderNameUploadLength = @"Upload-Length";
const OCTUSHeaderName OCTUSHeaderNameUploadMetadata = @"Upload-Metadata";

const OCTUSExtension OCTUSExtensionCreation = @"creation";
const OCTUSExtension OCTUSExtensionCreationWithUpload = @"creation-with-upload";
const OCTUSExtension OCTUSExtensionExpiration = @"expiration";
