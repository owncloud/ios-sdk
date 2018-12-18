//
//  XCTestCase+Tagging.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 13.12.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "XCTestCase+Tagging.h"

@implementation XCTestCase (Tagging)

#pragma mark - Tagging
+ (NSArray<OCLogTagName> *)logTags
{
	return (@[@"TEST", NSStringFromClass(self)]);
}

- (NSArray<OCLogTagName> *)logTags
{
	return ([NSArray arrayWithObjects: @"TEST", NSStringFromClass([self class]), [self nameOfCurrentTest], nil]);
}

- (NSString *)nameOfCurrentTest
{
	NSString *name = self.name;

	name = [name componentsSeparatedByString:@" "].lastObject;

	if ([name hasPrefix:@"test"])
	{
		name = [name substringWithRange:NSMakeRange(4, name.length-5)]; // remove trailing "]" and leading "test"
		return (name);
	}

	return (nil);
}

@end
