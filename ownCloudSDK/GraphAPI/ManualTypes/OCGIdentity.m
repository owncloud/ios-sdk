//
//  OCGIdentity.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 26.01.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

#import "OCGIdentity.h"

@implementation OCGIdentity

+ (nullable instancetype)decodeGraphData:(OCGraphData)structure context:(nullable OCGraphContext *)context error:(NSError * _Nullable * _Nullable)outError
{
	OCGIdentity *instance = [self new];

	OCG_SET(id, NSString);
	OCG_SET(displayName, NSString);

	return (instance);
}

@end
