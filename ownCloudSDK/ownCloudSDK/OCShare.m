//
//  OCShare.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCShare.h"

@implementation OCShare

@synthesize type;

@synthesize url;

@synthesize expirationDate;

@synthesize userIdentifiers;

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		self.type = [decoder decodeIntegerForKey:@"type"];
		self.url = [decoder decodeObjectOfClass:[NSURL class] forKey:@"url"];
		self.expirationDate = [decoder decodeObjectOfClass:[NSDate class] forKey:@"expirationDate"];
		self.userIdentifiers = [decoder decodeObjectOfClass:[NSArray class] forKey:@"userIdentifiers"];
	}
	
	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInteger:self.type forKey:@"type"];
	[coder encodeObject:self.url forKey:@"url"];
	[coder encodeObject:self.expirationDate forKey:@"expirationDate"];
	[coder encodeObject:self.userIdentifiers forKey:@"userIdentifiers"];
}

@end
