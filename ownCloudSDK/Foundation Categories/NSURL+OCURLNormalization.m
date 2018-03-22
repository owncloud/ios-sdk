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

+ (NSURL *)URLWithUsername:(NSString **)outUserName password:(NSString **)outPassword afterNormalizingURLString:(NSString *)urlString protocolWasPrepended:(BOOL *)outProtocolWasPrepended;
{
	NSURL *url = nil;
	NSString *lowerCaseURLString = nil;
	NSURLComponents *urlComponents = nil;
	NSRange range;
	
	// Remove whitespace and newline characters from both ends
	urlString = [urlString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
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
	
	// End URL with a slash
	if (![urlString hasSuffix:@"/"])
	{
		urlString = [urlString stringByAppendingString:@"/"];
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

		url = [urlComponents URL];
	}

	return (url);
}

@end
