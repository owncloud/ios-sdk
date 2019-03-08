//
//  OCHTTPResponse+DAVError.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 08.03.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCHTTPResponse+DAVError.h"
#import "OCXMLParser.h"
#import "OCXMLParserNode.h"

@implementation OCHTTPResponse (DAVError)

- (nullable NSError *)bodyParsedAsDAVError
{
	NSString *contentType = nil;
	NSError *error = nil;

	if ((contentType = self.headerFields[@"Content-Type"]) != nil)
	{
		if ([contentType hasPrefix:@"application/xml"])
		{
			OCXMLParser *parser = nil;

			if ((parser = [[OCXMLParser alloc] initWithData:self.bodyData]) != nil)
			{
				[parser addObjectCreationClasses:@[ [NSError class] ]];

				if ([parser parse])
				{
					for (NSError *parsedError in parser.errors)
					{
						if ([parsedError.domain isEqual:OCDAVErrorDomain])
						{
							error = parsedError;
							break;
						}
					}
				}
			}
		}
	}

	return (error);
}

@end
