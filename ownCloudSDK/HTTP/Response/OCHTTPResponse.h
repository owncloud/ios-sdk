//
//  OCHTTPResponse.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.02.19.
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

#import <Foundation/Foundation.h>
#import "OCHTTPTypes.h"
#import "OCCertificate.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCHTTPResponse : NSObject <NSSecureCoding>
{
	NSMutableData *_bodyData;
}

@property(strong) OCHTTPRequestID requestID;			//!< The OCHTTPRequestID this is the response to

@property(strong,nullable) OCCertificate *certificate;		//!< The certificate served by the server

@property(strong,nullable) OCHTTPStatus *httpStatus;		//!< The HTTP status returned by the server
@property(strong,nullable) NSHTTPURLResponse *response;		//!< The NSHTTPURLResponse returned by the server

@property(strong,nullable) NSURL *bodyURL;			//!< If non-nil, the URL at which the contents of the body is stored
@property(assign) OCHTTPStorageStatus bodyURLStorageStatus;	//!< Storage status of file located bodyURL

@property(strong,nullable) NSData *bodyData;			//!< If non-nil, the received data of the body. If .bodyURL is provided, maps the file into memory via -[NSData initWithContentsOfFile:bodyURL options:NSDataReadingMappedIfSafe|NSDataReadingUncached]

@property(readonly,strong,nonatomic,nullable) NSURL *redirectURL; //!< Convenience accessor for the URL contained in the response's Location header field

@property(strong,nullable) NSError *error;
@property(strong,nullable) NSError *httpError;

- (instancetype)initWithRequest:(OCHTTPRequest *)request; //!< Creates a OCHTTPResponse from a OCHTTPRequest.
- (instancetype)initWithHTTPError:(NSError *)error; //!< Creates a OCHTTPResponse with the provided HTTP error (usually networking errors).

- (void)appendDataToResponseBody:(NSData *)appendResponseBodyData;

- (NSString *)bodyAsString; //!< Returns the response body as a string formatted using the text encoding provided by the server. If no text encoding is provided, ISO-8859-1 is used.

- (NSDictionary *)bodyConvertedDictionaryFromJSONWithError:(NSError **)outError; //!< Returns the response body as dictionary as converted by the JSON deserializer
- (NSArray *)bodyConvertedArrayFromJSONWithError:(NSError **)error; //!< Returns the response body as array as converted by the JSON deserializer

@end

NS_ASSUME_NONNULL_END
