//
//  OCConnection+Search.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 31.10.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCConnection.h"
#import "OCXMLNode.h"
#import "OCHTTPDAVRequest.h"
#import "NSError+OCError.h"
#import "OCMacros.h"

@implementation OCConnection (Search)

- (nullable OCProgress *)searchFilesWithPattern:(NSString *)pattern limit:(nullable NSNumber *)limit options:(nullable NSDictionary<OCConnectionOptionKey,id> *)options resultTarget:(OCEventTarget *)eventTarget
{
	NSURL *endpointURL = [self URLForEndpoint:OCConnectionEndpointIDWebDAVSpaces options:nil];
	NSMutableArray<OCXMLNode *> *searchNodes = [NSMutableArray new];
	NSMutableArray<OCXMLNode *> *propertyNodes = [self _davItemAttributes];
	OCHTTPDAVRequest *request;

	if (endpointURL == nil)
	{
		// WebDAV root could not be generated (likely due to lack of username)
		[eventTarget handleError:OCError(OCErrorInternal) type:OCEventTypeSearch uuid:nil sender:self];

		return (nil);
	}

	if (pattern != nil)
	{
		[searchNodes addObject:[OCXMLNode elementWithName:@"oc:pattern" stringValue:pattern]];
	}

	if (limit != nil)
	{
		[searchNodes addObject:[OCXMLNode elementWithName:@"oc:limit" stringValue:limit.stringValue]];
	}

	if (searchNodes.count == 0)
	{
		[eventTarget handleError:OCError(OCErrorInsufficientParameters) type:OCEventTypeSearch uuid:nil sender:self];
		return(nil);
	}

	request = [OCHTTPDAVRequest reportRequestWithURL:endpointURL rootElementName:@"oc:search-files" content:[[NSArray alloc] initWithObjects:
		[OCXMLNode elementWithName:@"D:prop" children:propertyNodes],
		[OCXMLNode elementWithName:@"oc:search" children:searchNodes],
	nil]];
	request.eventTarget = eventTarget;
	request.resultHandlerAction = @selector(_handleSearchResult:error:);
	request.requiredSignals = self.propFindSignals;

	// Attach to pipelines
	[self attachToPipelines];

	// Enqueue request
	[self.ephermalPipeline enqueueRequest:request forPartitionID:self.partitionID];

	return (request.progress);
}

- (void)_handleSearchResult:(OCHTTPRequest *)request error:(NSError *)error
{
	OCEvent *event;

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeSearch uuid:request.identifier attributes:nil]) != nil)
	{
		if (error != nil)
		{
			event.error = error;
		}
		else if (request.error != nil)
		{
			event.error = request.error;
		}
		else
		{
			if (request.httpResponse.status.isSuccess)
			{
				NSArray<OCItem *> *items = nil;
				NSArray <NSError *> *errors = nil;
				NSURL *endpointURL = [self URLForEndpoint:OCConnectionEndpointIDWebDAVSpaces options:nil];

				if (endpointURL != nil)
				{
					if ((items = [((OCHTTPDAVRequest *)request) responseItemsForBasePath:endpointURL.path drives:_drives reuseUsersByID:self->_usersByUserID driveID:nil withErrors:&errors]) != nil)
					{
						event.result = items;
					}
					else
					{
						event.error = errors.firstObject;
					}
				}
				else
				{
					// WebDAV root could not be generated (likely due to lack of username)
					event.error = OCError(OCErrorInternal);
				}
			}
			else
			{
				event.error = request.httpResponse.status.error;
			}
		}
	}

	if (event != nil)
	{
		OCErrorAddDateFromResponse(event.error, request.httpResponse);
		[request.eventTarget handleEvent:event sender:self];
	}
}


@end
