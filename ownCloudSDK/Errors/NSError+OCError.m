//
//  NSError+OCError.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.02.18.
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

#import "NSError+OCError.h"

@implementation NSError (OCError)

+ (instancetype)errorWithOCError:(OCError)errorCode
{
	return ([NSError errorWithOCError:errorCode userInfo:nil]);
}

+ (instancetype)errorWithOCError:(OCError)errorCode userInfo:(NSDictionary<NSErrorUserInfoKey,id> *)userInfo
{
	return ([NSError errorWithDomain:OCErrorDomain code:errorCode userInfo:userInfo]);
}

- (BOOL)isOCError
{
	return ([self.domain isEqual:OCErrorDomain]);
}

- (BOOL)isOCErrorWithCode:(OCError)errorCode
{
	return ([self.domain isEqual:OCErrorDomain] && (self.code == errorCode));
}

- (NSError *)errorByEmbeddingIssue:(OCConnectionIssue *)issue
{
	NSMutableDictionary *userInfo = nil;
	
	if (issue==nil) { return(self); }
	
	if (self.userInfo != nil)
	{
		userInfo = [NSMutableDictionary dictionaryWithDictionary:self.userInfo];
	}
	else
	{
		userInfo = [NSMutableDictionary dictionary];
	}
	
	userInfo[OCErrorIssueKey] = issue;
	
	return ([NSError errorWithDomain:self.domain code:self.code userInfo:userInfo]);
}

- (OCConnectionIssue *)embeddedIssue
{
	return (self.userInfo[OCErrorIssueKey]);
}

- (NSDictionary *)ocErrorInfoDictionary
{
	NSDictionary *errorInfoDictionary;
	
	if ((errorInfoDictionary = self.userInfo[OCErrorInfoKey]) != nil)
	{
		if ([errorInfoDictionary isKindOfClass:[NSDictionary class]])
		{
			return(errorInfoDictionary);
		}
	}
	
	return (nil);
}

@end

NSErrorDomain OCErrorDomain = @"OCError";

NSString *OCErrorInfoKey = @"OCErrorInfo";
NSString *OCErrorIssueKey = @"OCErrorIssue";
