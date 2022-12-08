//
//  OCCertificateStore.m
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

#import "OCCertificateStore.h"
#import "OCCertificateStoreRecord.h"

@implementation OCCertificateStore
{
	NSMutableDictionary<NSString *, OCCertificateStoreRecord *> *_recordsByHostname;
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_recordsByHostname = [NSMutableDictionary new];
	}

	return (self);
}

#pragma mark - Store & retrieve certificates
- (void)storeCertificate:(OCCertificate *)certificate forHostname:(NSString *)hostname
{
	if ((hostname != nil) && (hostname.length > 0))
	{
		@synchronized(_recordsByHostname)
		{
			_recordsByHostname[hostname] = [[OCCertificateStoreRecord alloc] initWithCertificate:certificate forHostname:hostname];
		}
	}
}

- (nullable OCCertificate *)certificateForHostname:(NSString *)hostname lastModified:(NSDate * _Nullable * _Nullable)outLastModified
{
	OCCertificateStoreRecord *record = nil;

	if ((hostname != nil) && (hostname.length > 0))
	{
		@synchronized(_recordsByHostname)
		{
			record = _recordsByHostname[hostname];
		}
	}

	return (record.certificate);
}

- (NSArray<NSString *> *)hostnamesForCertificate:(OCCertificate *)certificate
{
	NSMutableSet<NSString *> *hostnames = [NSMutableSet new];

	@synchronized(_recordsByHostname) {
		[_recordsByHostname enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull hostname, OCCertificateStoreRecord * _Nonnull record, BOOL * _Nonnull stop) {
			if ([record.certificate isEqual:certificate])
			{
				[hostnames addObject:record.hostname];
			}
		}];
	}

	return ((hostnames.count > 0) ? hostnames.allObjects : nil);
}

#pragma mark - Remove certificates
- (BOOL)removeCertificateForHostname:(NSString *)hostname
{
	if ((hostname != nil) && (hostname.length > 0))
	{
		@synchronized(_recordsByHostname)
		{
			if (_recordsByHostname[hostname] != nil)
			{
				_recordsByHostname[hostname] = nil;
				return (YES);
			}
		}
	}

	return (NO);
}

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder
{
	[coder encodeObject:_recordsByHostname forKey:@"recordsByHostname"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
	if ((self = [self init]) != nil)
	{
		_recordsByHostname = [coder decodeObjectOfClasses:[NSSet setWithObjects:OCCertificateStoreRecord.class, NSDictionary.class, nil] forKey:@"recordsByHostname"];
	}

	return (self);
}

@end
