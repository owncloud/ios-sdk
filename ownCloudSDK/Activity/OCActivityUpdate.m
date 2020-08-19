//
//  OCActivityUpdate.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.01.19.
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

#import "OCActivityUpdate.h"

@implementation OCActivityUpdate

@synthesize type = _type;
@synthesize identifier = _identifier;
@synthesize updatesByKeyPath = _updatesByKeyPath;

+ (instancetype)publishingActivity:(OCActivity *)activity
{
	OCActivityUpdate *update = [OCActivityUpdate new];

	update->_type = OCActivityUpdateTypePublish;
	update->_activity = activity;
	update->_identifier = activity.identifier;

	return (update);
}

+ (instancetype)unpublishActivityForIdentifier:(OCActivityIdentifier)identifier
{
	OCActivityUpdate *update = [OCActivityUpdate new];

	update->_type = OCActivityUpdateTypeUnpublish;
	update->_identifier = identifier;

	return (update);
}

+ (instancetype)updatingActivityForIdentifier:(OCActivityIdentifier)identifier
{
	OCActivityUpdate *update = [OCActivityUpdate new];

	update->_type = OCActivityUpdateTypeProperty;
	update->_identifier = identifier;

	return (update);
}

+ (instancetype)publishingActivityFor:(id<OCActivitySource>)source
{
	return ([self publishingActivity:[source provideActivity]]);
}

+ (instancetype)unpublishActivityFor:(id<OCActivitySource>)source
{
	return ([self unpublishActivityForIdentifier:source.activityIdentifier]);
}

+ (instancetype)updatingActivityFor:(id<OCActivitySource>)source;
{
	return ([self updatingActivityForIdentifier:source.activityIdentifier]);
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_updatesByKeyPath = [NSMutableDictionary new];
	}

	return(self);
}

- (instancetype)withStatusMessage:(NSString *)statusMessage
{
	_updatesByKeyPath[@"localizedStatusMessage"] = statusMessage;

	return (self);
}

- (instancetype)withProgress:(nullable NSProgress *)progress
{
	_updatesByKeyPath[@"progress"] = progress;

	return (self);
}

- (instancetype)withState:(OCActivityState)state
{
	_updatesByKeyPath[@"state"] = @(state);

	return (self);
}

@end
