//
//  OCHTTPStatus.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.02.18.
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

typedef NS_ENUM(NSUInteger, OCHTTPStatusCode)
{
	// Success (2xx)
	OCHTTPStatusCodeOK = 200,
	OCHTTPStatusCodeCREATED = 201,
	OCHTTPStatusCodeNO_CONTENT = 204,
	OCHTTPStatusCodePARTIAL_CONTENT = 206,

	// Redirection (3xx)
	OCHTTPStatusCodeMOVED_PERMANENTLY = 301,
	OCHTTPStatusCodeMOVED_TEMPORARILY = 302,

	// Client Error (4xx)
	OCHTTPStatusCodeBAD_REQUEST = 400,
	OCHTTPStatusCodeUNAUTHORIZED = 401,
	OCHTTPStatusCodeFORBIDDEN = 403,

	// Server Error (5xx)
	OCHTTPStatusCodeINTERNAL_SERVER_ERROR = 500,
	OCHTTPStatusCodeNOT_IMPLEMENTED = 501
};

@interface OCHTTPStatus : NSObject
{
	OCHTTPStatusCode _code;
}

@property(assign) OCHTTPStatusCode code;

@property(readonly,nonatomic) BOOL isSuccess;
@property(readonly,nonatomic) BOOL isRedirection;
@property(readonly,nonatomic) BOOL isError;

+ (instancetype)HTTPStatusWithCode:(OCHTTPStatusCode)code;

- (NSError *)error;
- (NSError *)errorWithURL:(NSURL *)url;
- (NSError *)errorWithResponse:(NSHTTPURLResponse *)response;


@end

extern NSErrorDomain OCHTTPStatusErrorDomain;
