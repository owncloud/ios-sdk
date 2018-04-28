//
//  NSProgress+OCExtensions.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.04.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "NSProgress+OCExtensions.h"

@implementation NSProgress (OCExtensions)

+ (instancetype)indeterminateProgress
{
	return ([NSProgress progressWithTotalUnitCount:0]);
}

@end
