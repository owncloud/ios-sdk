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

typedef void(^OCHostSimulatorResponseHandler)(NSError *error, OCHostSimulatorResponse *response);

typedef BOOL(^OCHostSimulatorRequestHandler)(OCConnection *connection, OCConnectionRequest *request, OCHostSimulatorResponseHandler responseHandler);

@interface OCHostSimulator : NSObject <OCConnectionHostSimulator>

@property(strong) OCCertificate *certificate;
@property(strong) NSString *hostname;

@property(strong) NSDictionary <NSString *, OCHostSimulatorResponse *> *responseByPath;

@property(copy) OCHostSimulatorRequestHandler requestHandler;
@property(copy) OCHostSimulatorRequestHandler unroutableRequestHandler;

@end
