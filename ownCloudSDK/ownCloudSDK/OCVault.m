//
//  OCVault.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCVault.h"
#import "OCAppIdentity.h"

@implementation OCVault

@synthesize uuid;

@synthesize database;

@synthesize rootURL;

#pragma mark - Init
- (instancetype)init
{
	return (nil);
}

- (instancetype)initWithBookmark:(OCBookmark *)bookmark
{
	if ((self = [super init]) != nil)
	{
		_uuid = bookmark.uuid;
	}
	
	return (self);
}

- (NSURL *)rootURL
{
	if (_rootURL == nil)
	{
		_rootURL = [[[OCAppIdentity sharedAppIdentity] appGroupContainerURL] URLByAppendingPathComponent:[self.uuid UUIDString]];
	}
	
	return (_rootURL);
}

@end
