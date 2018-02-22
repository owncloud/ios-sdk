//
//  OCConnectionRequest.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.02.18.
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

#import "OCConnectionRequest.h"

@implementation OCConnectionRequest

@synthesize urlSessionTask = _urlSessionTask;
@synthesize activity = _activity;

@synthesize bookmarkUUID = _bookmarkUUID;

@synthesize url = _url;
@synthesize method = _method;
@synthesize headerFields = _headerFields;
@synthesize bodyData = _bodyData;
@synthesize bodyURL = _bodyURL;

@synthesize resultHandlerAction = _resultHandlerAction;
@synthesize eventTarget = _eventTarget;

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		NSString *resultHandlerActionString;

		self.url 		= [decoder decodeObjectOfClass:[NSURL class] forKey:@"url"];

		self.bookmarkUUID	= [decoder decodeObjectOfClass:[NSUUID class] forKey:@"bookmarkUUID"];
		self.method		= [decoder decodeObjectOfClass:[NSString class] forKey:@"method"];
		self.headerFields 	= [decoder decodeObjectOfClass:[NSDictionary class] forKey:@"headerFields"];
		self.bodyData 		= [decoder decodeObjectOfClass:[NSData class] forKey:@"bodyData"];
		self.bodyURL 		= [decoder decodeObjectOfClass:[NSURL class] forKey:@"bodyURL"];
		self.eventTarget 	= [decoder decodeObjectOfClass:[OCEventTarget class] forKey:@"eventTarget"];

		if ((resultHandlerActionString = [decoder decodeObjectOfClass:[NSString class] forKey:@"resultHandlerAction"]) != nil)
		{
			self.resultHandlerAction= NSSelectorFromString(resultHandlerActionString);
		}
	}
	
	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_bookmarkUUID	forKey:@"bookmarkUUID"];
	[coder encodeObject:_url 		forKey:@"url"];
	[coder encodeObject:_method 		forKey:@"method"];
	[coder encodeObject:_headerFields 	forKey:@"headerFields"];
	[coder encodeObject:_bodyData 		forKey:@"bodyData"];
	[coder encodeObject:_bodyURL 		forKey:@"bodyURL"];
	[coder encodeObject:_eventTarget 	forKey:@"eventTarget"];

	[coder encodeObject:NSStringFromSelector(_resultHandlerAction) forKey:@"resultHandlerAction"];
}

@end

OCConnectionRequestMethod OCConnectionRequestMethodGET = @"GET";
OCConnectionRequestMethod OCConnectionRequestMethodPOST = @"POST";
OCConnectionRequestMethod OCConnectionRequestMethodHEAD = @"HEAD";
OCConnectionRequestMethod OCConnectionRequestMethodPUT = @"PUT";
OCConnectionRequestMethod OCConnectionRequestMethodDELETE = @"DELETE";
OCConnectionRequestMethod OCConnectionRequestMethodMKCOL = @"MKCOL";
OCConnectionRequestMethod OCConnectionRequestMethodOPTIONS = @"OPTIONS";
OCConnectionRequestMethod OCConnectionRequestMethodMOVE = @"MOVE";
OCConnectionRequestMethod OCConnectionRequestMethodCOPY = @"COPY";
OCConnectionRequestMethod OCConnectionRequestMethodPROPFIND = @"PROPFIND";
OCConnectionRequestMethod OCConnectionRequestMethodPROPPATCH = @"PROPPATCH";
OCConnectionRequestMethod OCConnectionRequestMethodLOCK = @"LOCK";
OCConnectionRequestMethod OCConnectionRequestMethodUNLOCK = @"UNLOCK";

