//
//  OCConnectionRequest.h
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

#import <Foundation/Foundation.h>
#import "OCEventTarget.h"
#import "OCActivity.h"
#import "OCBookmark.h"

typedef NSString* OCConnectionRequestMethod NS_TYPED_ENUM;
typedef NSMutableDictionary<NSString*,NSString*>* OCConnectionHeaderFields;
typedef NSMutableDictionary<NSString*,NSString*>* OCConnectionParameters;

typedef float OCConnectionRequestPriority;
typedef NSString* OCConnectionRequestGroupID;

@interface OCConnectionRequest : NSObject <NSSecureCoding>
{
	NSURLSessionTask *_urlSessionTask;
	OCActivity *_activity;

	OCBookmarkUUID _bookmarkUUID;

	OCConnectionRequestMethod _method;

	NSURL *_url;
	OCConnectionParameters _parameters;
	OCConnectionHeaderFields _headerFields;
	NSData *_bodyData;
	NSURL *_bodyURL;
	NSInputStream *_bodyURLInputStream;

	SEL _action;
	OCEventTarget *_resultTarget;
}

@property(strong) NSURLSessionTask *urlSessionTask;	//!< NSURLSessionTask used to perform the request [not serialized]
@property(strong) OCActivity *activity;			//!< Activity that tracks progress and provides cancellation ability/status [not serialized]

@property(strong) OCBookmarkUUID bookmarkUUID;		//!< UUID identifying the Bookmark that this request's connection is related to. Identifies the connection so that background queue results can be delivered correctly.

@property(strong) OCConnectionRequestMethod method;	//!< The HTTP method to use to request the URL

@property(strong) NSURL *url;				//!< The URL to request
@property(strong) OCConnectionParameters parameters;	//!< The parameters to send as part of the URL (GET) or as the request's body (POST)
@property(strong) OCConnectionHeaderFields headerFields;//!< The HTTP headerfields to send alongside the request
@property(strong) NSData *bodyData;			//!< The HTTP body to send (as body data). Ignored / overwritten if .method is POST and .parameters has key-value pairs.
@property(strong) NSURL *bodyURL;			//!< The HTTP body to send (from a file). Ignored if .method is POST and .parameters has key-value pairs.

@property(assign) SEL resultHandlerAction;		//!< The selector to invoke on OCConnection when the request has concluded.
@property(strong) OCEventTarget *eventTarget;		//!< The target the parsed result should be delivered to as an event.

@property(assign) OCConnectionRequestPriority priority;	//!< Priority of the request from 0.0 (lowest priority) to 1.0 (highest priority).
@property(strong) OCConnectionRequestGroupID groupID; 	//!< ID of the Group the request belongs to (if any). Requests in the same group are executed serially, whereas requests that belong to no group are executed as soon as possible.

- (NSString *)valueForParameter:(NSString *)parameter;
- (void)setValue:(NSString *)value forParameter:(NSString *)parameter;

- (NSString *)valueForHeaderField:(NSString *)headerField;
- (void)setValue:(NSString *)value forHeaderField:(NSString *)headerField;

@end

extern OCConnectionRequestMethod OCConnectionRequestMethodGET;
extern OCConnectionRequestMethod OCConnectionRequestMethodPOST;
extern OCConnectionRequestMethod OCConnectionRequestMethodHEAD;
extern OCConnectionRequestMethod OCConnectionRequestMethodPUT;
extern OCConnectionRequestMethod OCConnectionRequestMethodDELETE;
extern OCConnectionRequestMethod OCConnectionRequestMethodMKCOL;
extern OCConnectionRequestMethod OCConnectionRequestMethodOPTIONS;
extern OCConnectionRequestMethod OCConnectionRequestMethodMOVE;
extern OCConnectionRequestMethod OCConnectionRequestMethodCOPY;
extern OCConnectionRequestMethod OCConnectionRequestMethodPROPFIND;
extern OCConnectionRequestMethod OCConnectionRequestMethodPROPPATCH;
extern OCConnectionRequestMethod OCConnectionRequestMethodLOCK;
extern OCConnectionRequestMethod OCConnectionRequestMethodUNLOCK;

