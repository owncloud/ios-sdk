//
//  OCCore+DirectURL.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 01.07.19.
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

#import "OCCore+DirectURL.h"
#import "NSError+OCError.h"

@implementation OCCore (DirectURL)

- (void)provideDirectURLForItem:(OCItem *)item allowFileURL:(BOOL)allowFileURL completionHandler:(void(^)(NSError * _Nullable error, NSURL * _Nullable url, NSDictionary<NSString*, NSString*> * _Nullable httpAuthHeaders))completionHandler
{
	NSError *error = nil;
	NSURL *url = nil;
	NSDictionary<NSString*, NSString*> *authHeaders = nil;

	if (item.type != OCItemTypeFile)
	{
		// Direct URLs can only be provided for files
		error = OCError(OCErrorFeatureNotSupportedForItem);
	}
	else
	{
		// Provide URL to local copy if one exists
		if (allowFileURL)
		{
			url = [self localCopyOfItem:item];
		}

		// Provide URL to file on server
		if (url == nil)
		{
			if ((item.path != nil) && ((url = [[self.connection URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:nil] URLByAppendingPathComponent:item.path]) != nil))
			{
				authHeaders = [self.connection.authenticationMethod authorizationHeadersForConnection:self.connection error:&error];
			}
			else
			{
				// URL could not be built (likely because user name is not available)
				error = OCError(OCErrorNotAvailableOffline);
			}
		}
	}

	completionHandler(error, ((error == nil) ? url : nil), ((error == nil) ? authHeaders : nil));
}

@end
