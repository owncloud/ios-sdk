//
//  OCEventQueue.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.09.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCEventQueue.h"

@implementation OCEventQueue

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_records = [NSMutableArray new];
		_usedUUIDs = [NSMutableArray new];
	}

	return (self);
}

- (BOOL)addEventRecord:(OCEventRecord *)eventRecord
{
	if ([_usedUUIDs containsObject:eventRecord.event.uuid])
	{
		// Reject (processed) duplicate
		return(NO);
	}

	for (OCEventRecord *record in _records)
	{
		if ([record.event.uuid isEqual:eventRecord.event.uuid])
		{
			// Reject (unprocessed) duplicate
			return(NO);
		}
	}

	// Add to records
	[_records addObject:eventRecord];

	return (YES);
}

- (BOOL)removeEventRecordForEventUUID:(OCEventUUID)uuid
{
	OCEventRecord *removeRecord = nil;

	for (OCEventRecord *record in _records)
	{
		if ([record.event.uuid isEqual:uuid])
		{
			removeRecord = record;
			break;
		}
	}

	if (removeRecord != nil)
	{
		// Remove event record for event
		[_records removeObjectIdenticalTo:removeRecord];

		// Add event UUID to used UUIDs
		[_usedUUIDs insertObject:uuid atIndex:0];

		// Keep no more than 100 used UUIDs
		while (_usedUUIDs.count > 100)
		{
			[_usedUUIDs removeLastObject];
		};
	}

	return (removeRecord != nil);
}

#pragma mark - Secure coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		_records = [decoder decodeObjectOfClasses:[[NSSet alloc] initWithObjects: [OCEventRecord class], [NSMutableArray class], nil] forKey:@"records"];
		_usedUUIDs = [decoder decodeObjectOfClasses:[[NSSet alloc] initWithObjects: [NSString class], [NSMutableArray class], nil] forKey:@"usedUUIDs"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_records forKey:@"records"];
	[coder encodeObject:_usedUUIDs forKey:@"usedUUIDs"];
}

@end
