//
//  OCGIdentitySet.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 26.01.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

#import "OCGIdentitySet.h"

@implementation OCGIdentitySet

+ (nullable instancetype)decodeGraphData:(OCGraphData)structure context:(nullable OCGraphContext *)context error:(NSError * _Nullable * _Nullable)outError
{
	OCGIdentitySet *instance = [self new];

	OCG_SET(application, OCGIdentity);
	OCG_SET(device, OCGIdentity);
	OCG_SET(user, OCGIdentity);

	return (instance);
}

@end
