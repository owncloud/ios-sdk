//
//  NSURL+OCURLNormalization.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 02.03.18.
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

#import "NSURL+OCURLNormalization.h"

@implementation NSURL (OCURLNormalization)

@dynamic effectivePort;

+ (NSURL *)URLWithUsername:(NSString **)outUserName password:(NSString **)outPassword afterNormalizingURLString:(NSString *)urlString protocolWasPrepended:(BOOL *)outProtocolWasPrepended;
{
	NSURL *url = nil;
	NSString *lowerCaseURLString = nil;
	NSURLComponents *urlComponents = nil;
	NSRange range;
	
	// Remove whitespace and newline characters from both ends
	urlString = [urlString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	// Remove multiple trailing slashes
	while ([urlString hasSuffix:@"//"])
	{
		// Remove last character
		urlString = [urlString substringWithRange:NSMakeRange(0, urlString.length-1)];
	};

	// Remove trailing /index.php
	if (([urlString hasSuffix:@"/index.php"]) && (range = [urlString rangeOfString:@"/index.php"]).location != NSNotFound)
	{
		urlString = [urlString substringToIndex:range.location+1];
	}

	// Search for and remove everything before /index.php/apps/
	if ((range = [urlString rangeOfString:@"/index.php/apps/"]).location != NSNotFound)
	{
		urlString = [urlString substringToIndex:range.location+1];
	}
	
	// Check for and add missing scheme to URL, consider people entering HTTP://, Https://, ..
	if ((lowerCaseURLString = [urlString lowercaseString]) != nil)
	{
		if (outProtocolWasPrepended != NULL) { *outProtocolWasPrepended = NO; }

		if (![lowerCaseURLString hasPrefix:@"http://"] && ![lowerCaseURLString hasPrefix:@"https://"])
		{
			// Default to HTTPS (as you do in 2018)
			if (outProtocolWasPrepended != NULL) { *outProtocolWasPrepended = YES; }
			urlString = [@"https://" stringByAppendingString:urlString];
		}
	}

	// Check for and extract username and password
	if ((urlComponents = [NSURLComponents componentsWithString:urlString]) != nil)
	{
		if (outUserName != NULL)
		{
			*outUserName = [urlComponents user];
		}

		if (outPassword != NULL)
		{
			*outPassword = [urlComponents password];
		}
		
		urlComponents.user = nil;
		urlComponents.password = nil;
		urlComponents.scheme = [urlComponents.scheme lowercaseString];

		// Add trailing slash to root directory URLs
		if ((urlComponents.path == nil) || ([urlComponents.path isEqual:@""]))
		{
			urlComponents.path = @"/";
		}

		url = [urlComponents URL];
	}

	return (url);
}

- (NSNumber *)effectivePort
{
	NSNumber *port = self.port;

	if (port == nil)
	{
		if      ([self.scheme isEqual:@"http"])  { port =  @(80); }
		else if ([self.scheme isEqual:@"https"]) { port = @(443); }
	}

	return (port);
}

- (BOOL)hasSameSchemeHostAndPortAs:(NSURL *)otherURL
{
	return ([otherURL.scheme isEqual:self.scheme] && [otherURL.host isEqual:self.host] && [otherURL.effectivePort isEqual:self.effectivePort]);
}

@end
