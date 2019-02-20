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
	NSURL *_bodyDataTemporaryFile;

	NSData *_mappedBodyData;
}

@property(strong) OCHTTPRequestID requestID;			//!< The OCHTTPRequestID this is the response to

@property(strong,nullable) OCCertificate *certificate;		//!< The certificate served by the server
@property(assign) OCCertificateValidationResult certificateValidationResult; //!< The result of the validation of the certificate (if any). OCCertificateValidationResultNone if no validation has been performed yet.
@property(strong,nullable) NSError *certificateValidationError; //!< Any error that occured during validation of the certificate (if any).

@property(strong,nullable) OCHTTPStatus *status;		//!< The HTTP status returned by the server
@property(strong,nullable) NSDictionary<NSString *, NSString *> *headerFields; //!< All HTTP header fields

@property(strong,nullable,nonatomic) NSHTTPURLResponse *httpURLResponse; //!< The NSHTTPURLResponse returned by the server. If set, is used to populate httpStatus and allHTTPHeaderFields.

@property(strong,nullable) NSURL *bodyURL;			//!< If non-nil, the URL at which the contents of the body is stored
@property(assign) BOOL bodyURLIsTemporary;			//!< Indicating whether the file stored as bodyURL is a temporary file. If you want to keep such a file around, you need to move it from bodyURL to a different location.

@property(strong,nullable,nonatomic) NSData *bodyData;			//!< If non-nil, the received data of the body. If .bodyURL is provided, maps the file into memory via -[NSData initWithContentsOfFile:bodyURL options:NSDataReadingMappedIfSafe|NSDataReadingUncached]

@property(readonly,strong,nonatomic,nullable) NSURL *redirectURL; //!< Convenience accessor for the URL contained in the response's Location header field

@property(strong,nullable) NSError *error;
@property(strong,nullable) NSError *httpError;

#pragma mark - Init
+ (instancetype)responseWithRequest:(OCHTTPRequest *)request HTTPError:(nullable NSError *)error; //!< Creates a OCHTTPResponse from a OCHTTPRequest. The HTTP error (usually networking/queue errors) is optional.

- (instancetype)initWithRequest:(OCHTTPRequest *)request HTTPError:(nullable NSError *)error; //!< Creates a OCHTTPResponse from a OCHTTPRequest. The HTTP error (usually networking/queue errors) is optional.

#pragma mark - Data receipt
- (void)appendDataToResponseBody:(NSData *)appendResponseBodyData; /* temporaryFileURL:(nullable NSURL *)temporaryFileURL; //!< Creates an internal buffer and adds the provided data. If the size passes 50 KB and temporaryFileURL is provided, moves the data to disk into temporaryFileURL; */

#pragma mark - Convenience accessors
- (nullable NSURL *)redirectURL; //!< URL contained in the response's Location header field

#pragma mark - Convenience body conversions
- (NSStringEncoding)bodyStringEncoding; //!< Returns the body's string encoding

- (nullable NSString *)bodyAsString; //!< Returns the response body as a string formatted using the text encoding provided by the server. If no text encoding is provided, ISO-8859-1 is used.

- (nullable NSDictionary *)bodyConvertedDictionaryFromJSONWithError:(NSError * _Nullable *)outError; //!< Returns the response body as dictionary as converted by the JSON deserializer
- (nullable NSArray *)bodyConvertedArrayFromJSONWithError:(NSError * _Nullable *)error; //!< Returns the response body as array as converted by the JSON deserializer

- (NSString *)responseDescription;

@end

NS_ASSUME_NONNULL_END
