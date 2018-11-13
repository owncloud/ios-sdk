//
//  OCQuery+OCMocking.h
//  ownCloudMocking
//
//  Created by Javier Gonzalez on 13/11/2018.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <ownCloudSDK/ownCloudSDK.h>
#import "OCMockManager.h"

@interface OCQuery (OCMocking)

- (void)ocm_requestChangeSetWithFlags:(OCQueryChangeSetRequestFlag)flags completionHandler:(void(^)(OCQueryChangeSetRequestCompletionHandler))completionHandler;

@end

typedef void(^OCMockOCConnectionGenerateAuthenticationDataWithMethodBlock)(OCAuthenticationMethodIdentifier methodIdentifier, OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions options, void(^completionHandler)(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData));

typedef void *(^OCMockOCQueryRequestChangeSetWithFlagsBlock)(OCQueryChangeSetRequestFlag flags, void(^completionHandler)(OCQueryChangeSetRequestCompletionHandler));
extern OCMockLocation OCMockLocationOCQueryRequestChangeSetWithFlags;
