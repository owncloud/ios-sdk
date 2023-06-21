//
//  OCCertificateStoreRecord.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 08.12.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCCertificateStoreRecord.h"
#import "OCMacros.h"

@implementation OCCertificateStoreRecord

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCertificate:(OCCertificate *)certificate forHostname:(NSString *)hostname
{
	return ([self initWithCertificate:certificate forHostname:hostname lastModifiedDate:NSDate.new]);
}

- (instancetype)initWithCertificate:(OCCertificate *)certificate forHostname:(NSString *)hostname lastModifiedDate:(NSDate *)lastModifiedDate;
{
	if ((self = [super init]) != nil)
	{
		_lastModifiedDate = lastModifiedDate;
		_certificate = certificate;
		_hostname = hostname;
	}

	return (self);
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder
{
	[coder encodeObject:_certificate forKey:@"certificate"];
	[coder encodeObject:_hostname forKey:@"hostname"];
	[coder encodeObject:_lastModifiedDate forKey:@"lastModifiedDate"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
	if ((self = [super init]) != nil)
	{
		_certificate = [coder decodeObjectOfClass:OCCertificate.class forKey:@"certificate"];
		_hostname = [coder decodeObjectOfClass:NSString.class forKey:@"hostname"];
		_lastModifiedDate = [coder decodeObjectOfClass:NSDate.class forKey:@"lastModifiedDate"];
	}

	return (self);
}

- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p%@%@%@>", NSStringFromClass(self.class), self,
		OCExpandVar(hostname),
		OCExpandVar(certificate),
		OCExpandVar(lastModifiedDate)
	]);
}

@end
