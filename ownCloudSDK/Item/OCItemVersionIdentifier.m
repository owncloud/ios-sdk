//
//  OCItemVersionIdentifier.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 26.04.18.
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

#import "OCItemVersionIdentifier.h"

@implementation OCItemVersionIdentifier

#pragma mark - Init & Dealloc
- (instancetype)initWithFileID:(OCFileID)fileID eTag:(OCFileETag)eTag
{
	if ((self = [super init]) != nil)
	{
		_eTag = eTag;
		_fileID = fileID;
	}

	return(self);
}

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_fileID    	forKey:@"fileID"];
	[coder encodeObject:_eTag    	forKey:@"eTag"];
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [self init]) != nil)
	{
		_fileID = [decoder decodeObjectOfClass:[NSString class] forKey:@"fileID"];
		_eTag = [decoder decodeObjectOfClass:[NSString class] forKey:@"eTag"];
	}

	return (self);
}

#pragma mark - Comparison
- (NSUInteger)hash
{
	return (_fileID.hash ^ _eTag.hash);
}

- (BOOL)isEqual:(id)object
{
	if (self == object) { return(YES); }

	if ([object isKindOfClass:[self class]])
	{
		return ([_fileID isEqual:((OCItemVersionIdentifier *)object).fileID] && [_eTag isEqual:((OCItemVersionIdentifier *)object).eTag]);
	}

	return (NO);
}

#pragma mark - Copying
- (nonnull id)copyWithZone:(nullable NSZone *)zone
{
	return (self);
}

#pragma mark - Description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p, fileID: %@, eTag: %@>", NSStringFromClass(self.class), self, _fileID, _eTag]);
}

@end
