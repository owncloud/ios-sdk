//
//  OCHostSimulatorResponse.h
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 20.03.18.
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
#import "OCHTTPStatus.h"

@interface OCHostSimulatorResponse : NSObject

@property(strong) NSURL *url; //!< URL of the response. If nil, the OCHostSimulator will set this property prior to calling .response.

@property(assign) OCHTTPStatusCode statusCode; //!< HTTP Status Code of the response
@property(strong) NSDictionary<NSString *,NSString *> *httpHeaders; //!< HTTP headers of the response

@property(strong,nonatomic) NSHTTPURLResponse *response; //!< Can either be set directly - or is built for you from .statusCode and .httpHeaders

@property(strong,nonatomic) NSData *bodyData; //!< Data making up the body of the HTTP response
@property(strong,nonatomic) NSURL *bodyURL; //!< URL to the file containing the data making up the body of the HTTP response

+ (instancetype)responseWithURL:(NSURL *)url statusCode:(OCHTTPStatusCode)statusCode headers:(NSDictionary<NSString *,NSString *> *)headers contentType:(NSString *)contentType bodyData:(NSData *)bodyData;
+ (instancetype)responseWithURL:(NSURL *)url statusCode:(OCHTTPStatusCode)statusCode headers:(NSDictionary<NSString *,NSString *> *)headers contentType:(NSString *)contentType body:(NSString *)bodyString;

@end
