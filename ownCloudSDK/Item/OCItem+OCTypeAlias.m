//
//  OCItem+OCTypeAlias.m
//  ownCloudApp
//
//  Created by Felix Schwarz on 12.09.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCItem+OCTypeAlias.h"
#import "OCLogger.h"

@implementation OCItem (MIMETypeAliases)

+ (NSDictionary<NSString *, NSString *> *)mimeTypeToAliasesMap
{
	static dispatch_once_t onceToken;
	static NSDictionary<NSString *, NSString *> *mimeTypeAliases;

	dispatch_once(&onceToken, ^{
		mimeTypeAliases = @{
			// List taken from https://github.com/owncloud/core/blob/master/resources/config/mimetypealiases.dist.json on 2022-09-12
			// (previously taken from https://github.com/owncloud/core/blob/master/core/js/mimetypelist.js)
			@"application/coreldraw": @"image",
			@"application/epub+zip": @"text",
			@"application/font-sfnt": @"image",
			@"application/font-woff": @"image",
			@"application/gzip": @"package/x-generic",
			@"application/illustrator": @"image",
			@"application/javascript": @"text/code",
			@"application/json": @"text/code",
			@"application/msaccess": @"file",
			@"application/msexcel": @"x-office/spreadsheet",
			@"application/msonenote": @"x-office/document",
			@"application/mspowerpoint": @"x-office/presentation",
			@"application/msword": @"x-office/document",
			@"application/octet-stream": @"file",
			@"application/postscript": @"image",
			@"application/rss+xml": @"application/xml",
			@"application/vnd.android.package-archive": @"package/x-generic",
			@"application/vnd.lotus-wordpro": @"x-office/document",
			@"application/vnd.ms-excel": @"x-office/spreadsheet",
			@"application/vnd.ms-excel.addin.macroEnabled.12": @"x-office/spreadsheet",
			@"application/vnd.ms-excel.sheet.binary.macroEnabled.12": @"x-office/spreadsheet",
			@"application/vnd.ms-excel.sheet.macroEnabled.12": @"x-office/spreadsheet",
			@"application/vnd.ms-excel.template.macroEnabled.12": @"x-office/spreadsheet",
			@"application/vnd.ms-fontobject": @"image",
			@"application/vnd.ms-powerpoint": @"x-office/presentation",
			@"application/vnd.ms-powerpoint.addin.macroEnabled.12": @"x-office/presentation",
			@"application/vnd.ms-powerpoint.presentation.macroEnabled.12": @"x-office/presentation",
			@"application/vnd.ms-powerpoint.slideshow.macroEnabled.12": @"x-office/presentation",
			@"application/vnd.ms-powerpoint.template.macroEnabled.12": @"x-office/presentation",
			@"application/vnd.ms-word.document.macroEnabled.12": @"x-office/document",
			@"application/vnd.ms-word.template.macroEnabled.12": @"x-office/document",
			@"application/vnd.oasis.opendocument.presentation": @"x-office/presentation",
			@"application/vnd.oasis.opendocument.presentation-template": @"x-office/presentation",
			@"application/vnd.oasis.opendocument.spreadsheet": @"x-office/spreadsheet",
			@"application/vnd.oasis.opendocument.spreadsheet-template": @"x-office/spreadsheet",
			@"application/vnd.oasis.opendocument.text": @"x-office/document",
			@"application/vnd.oasis.opendocument.text-master": @"x-office/document",
			@"application/vnd.oasis.opendocument.text-template": @"x-office/document",
			@"application/vnd.oasis.opendocument.text-web": @"x-office/document",
			@"application/vnd.oasis.opendocument.graphics-flat-xml": @"x-office/drawing",
			@"application/vnd.oasis.opendocument.graphics": @"x-office/drawing",
			@"application/vnd.oasis.opendocument.graphics-template": @"x-office/drawing",
			@"application/vnd.openxmlformats-officedocument.presentationml.presentation": @"x-office/presentation",
			@"application/vnd.openxmlformats-officedocument.presentationml.slideshow": @"x-office/presentation",
			@"application/vnd.openxmlformats-officedocument.presentationml.template": @"x-office/presentation",
			@"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": @"x-office/spreadsheet",
			@"application/vnd.openxmlformats-officedocument.spreadsheetml.template": @"x-office/spreadsheet",
			@"application/vnd.openxmlformats-officedocument.wordprocessingml.document": @"x-office/document",
			@"application/vnd.openxmlformats-officedocument.wordprocessingml.template": @"x-office/document",
			@"application/vnd.visio": @"x-office/document",
			@"application/vnd.wordperfect": @"x-office/document",
			@"application/x-7z-compressed": @"package/x-generic",
			@"application/x-bzip2": @"package/x-generic",
			@"application/x-cbr": @"text",
			@"application/x-compressed": @"package/x-generic",
			@"application/x-dcraw": @"image",
			@"application/x-deb": @"package/x-generic",
			@"application/x-font": @"image",
			@"application/x-gimp": @"image",
			@"application/x-gzip": @"package/x-generic",
			@"application/x-perl": @"text/code",
			@"application/x-photoshop": @"image",
			@"application/x-php": @"text/code",
			@"application/x-rar-compressed": @"package/x-generic",
			@"application/x-tar": @"package/x-generic",
			@"application/x-tex": @"text",
			@"application/xml": @"text/html",
			@"application/yaml": @"text/code",
			@"application/zip": @"package/x-generic",
			@"database": @"file",
			@"httpd/unix-directory": @"dir",
			@"message/rfc822": @"text",
			@"text/css": @"text/code",
			@"text/csv": @"x-office/spreadsheet",
			@"text/html": @"text/code",
			@"text/x-c": @"text/code",
			@"text/x-c++src": @"text/code",
			@"text/x-h": @"text/code",
			@"text/x-java-source": @"text/code",
			@"text/x-python": @"text/code",
			@"text/x-shellscript": @"text/code",
			@"web": @"text/code"
		};
	});

	return (mimeTypeAliases);
}

+ (OCTypeAlias)typeAliasForMIMEType:(OCMIMEType)mimeType
{
	static dispatch_once_t onceToken;
	static NSMutableDictionary<OCMIMEType, OCTypeAlias> *typeAliasByMIMEType;
	dispatch_once(&onceToken, ^{
		typeAliasByMIMEType = [[NSMutableDictionary alloc] initWithDictionary:self.mimeTypeToAliasesMap];
	});

	if (mimeType == nil)
	{
		return (nil);
	}

	OCTypeAlias typeAlias;

	if ((typeAlias = typeAliasByMIMEType[mimeType]) == nil)
	{
		typeAlias = [OCTypeAliasMIMEPrefix stringByAppendingString:mimeType];
		typeAliasByMIMEType[mimeType] = typeAlias;
	}

	return (typeAlias);
}


+ (NSArray<NSString *> *)mimeTypesMatching:(BOOL(^)(NSString *mimeType, NSString *alias))matcher
{
	NSMutableArray<NSString *> *matchedMIMETypes = [NSMutableArray new];

	[self.mimeTypeToAliasesMap enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull mimeType, NSString * _Nonnull alias, BOOL * _Nonnull stop) {
		if (matcher(mimeType, alias))
		{
			[matchedMIMETypes addObject:mimeType];
		}
	}];

	return (matchedMIMETypes);
}

- (OCTypeAlias)typeAlias
{
	return ([OCItem typeAliasForMIMEType:self.mimeType]);
}

@end

OCTypeAlias OCTypeAliasMIMEPrefix = @"MIME:";
