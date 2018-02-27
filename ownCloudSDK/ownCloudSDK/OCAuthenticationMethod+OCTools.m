//
//  OCAuthenticationMethod+OCTools.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 26.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCAuthenticationMethod+OCTools.h"

@implementation OCAuthenticationMethod (OCTools)

+ (NSString *)basicAuthorizationValueForUsername:(NSString *)username passphrase:(NSString *)passPhrase
{
	return ([NSString stringWithFormat:@"Basic %@", [[[NSString stringWithFormat:@"%@:%@", username, passPhrase] dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]]);
}

@end
