//
//  OCKeychain.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 16.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OCKeychain : NSObject
{
	NSString *_accessGroupIdentifier;
}

- (instancetype)initWithAccessGroupIdentifier:(NSString *)accessGroupIdentifier;

- (NSData *)readDataFromKeychainItemForAccount:(NSString *)account path:(NSString *)path;
- (NSError *)writeData:(NSData *)data toKeychainItemForAccount:(NSString *)account path:(NSString *)path;
- (NSError *)removeKeychainItemForAccount:(NSString *)account path:(NSString *)path;

@end
