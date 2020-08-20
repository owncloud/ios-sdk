//
//  OCHostSimulator.h
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
#import <ownCloudSDK/ownCloudSDK.h>

#import "OCHostSimulatorResponse.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^OCHostSimulatorResponseHandler)(NSError * _Nullable error, OCHostSimulatorResponse * _Nullable response);
typedef BOOL(^OCHostSimulatorRequestHandler)(OCConnection *connection, OCHTTPRequest *request, OCHostSimulatorResponseHandler responseHandler);

@interface OCHostSimulator : NSObject <OCConnectionHostSimulator>

@property(nullable,strong) OCCertificate *certificate;
@property(nullable,strong) NSString *hostname;

@property(nullable,strong) NSDictionary <NSString *, OCHostSimulatorResponse *> *responseByPath;

@property(nullable,copy) OCHostSimulatorRequestHandler requestHandler;
@property(nullable,copy) OCHostSimulatorRequestHandler unroutableRequestHandler;

@end

NS_ASSUME_NONNULL_END
