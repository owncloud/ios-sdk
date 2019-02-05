//
//  OCHTTPDAVMultistatusResponse.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 13.11.18.
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
#import "OCXMLParser.h"
#import "OCHTTPStatus.h"
#import "OCTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCHTTPDAVMultistatusResponse : NSObject <OCXMLObjectCreation>

				  	// status code	   	// propName    // string value or NSNull.null
@property(strong,readonly) NSDictionary <OCHTTPStatus *, NSDictionary <NSString *, id> *> *valueForPropByStatusCode;
@property(strong,readonly) OCPath path;

- (nullable OCHTTPStatus *)statusForProperty:(NSString *)propertyName;

@end

NS_ASSUME_NONNULL_END
