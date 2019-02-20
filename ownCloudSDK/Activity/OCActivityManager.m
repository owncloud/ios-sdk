//
//  OCActivityManager.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 25.01.19.
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

#import "OCActivityManager.h"
#import "OCActivityUpdate.h"
#import "OCLogger.h"

@interface OCActivityManager ()
{
	NSMutableArray <OCActivity *> *_activities;
	NSMutableDictionary <OCActivityIdentifier, OCActivity *> *_activityByIdentifier;
	NSArray <OCActivity *> *_exposedActivities;
	NSMutableArray <NSDictionary<NSString *, id<NSObject>> *> *_queuedActivityUpdates;
	NSNotificationName _activityUpdateNotificationName;
}

@end

@implementation OCActivityManager

#pragma mark - Init & Dealloc
- (instancetype)initWithUpdateNotificationName:(NSString *)updateNotificationName
{
	if ((self = [super init]) != nil)
	{
		_activities = [NSMutableArray new];
		_activityByIdentifier = [NSMutableDictionary new];
		_queuedActivityUpdates = [NSMutableArray new];
		_activityUpdateNotificationName = updateNotificationName;
	}

	return(self);
}

- (NSNotificationName)activityUpdateNotificationName
{
	return (_activityUpdateNotificationName);
}

- (NSArray<OCActivity *> *)activities
{
	NSArray<OCActivity *> *activities = nil;

	@synchronized (_activities)
	{
		if (_exposedActivities == nil)
		{
			_exposedActivities = [[NSArray alloc] initWithArray:_activities];
		}

		activities = _exposedActivities;
	}

	return (activities);
}

- (void)update:(OCActivityUpdate *)update
{
	__block OCActivity *updatedActivity = nil;

	switch (update.type)
	{
		case OCActivityUpdateTypePublish: {
			OCActivity *newActivity = update.activity;

			if (newActivity == nil)
			{
				OCLogError(@"Activity missing from Publish-ActivityUpdate: %@", update);
			}
			else if (newActivity.identifier == nil)
			{
				OCLogError(@"Publish-ActivityUpdate: activity lacks identifer: %@", update);
			}
			else
			{
				@synchronized(_activities)
				{
					[_activities addObject:newActivity];
					[_activities sortUsingDescriptors:@[ [NSSortDescriptor sortDescriptorWithKey:@"ranking" ascending:YES] ]];
					_activityByIdentifier[newActivity.identifier] = newActivity;

					_exposedActivities = nil;
				}

				updatedActivity = newActivity;
			}
		}
		break;

		case OCActivityUpdateTypeProperty: {
			OCActivityIdentifier activityIdentifier = update.identifier;

			if (activityIdentifier == nil)
			{
				OCLogError(@"Property-ActivityUpdate: update lacks identifer: %@", update);
			}
			else
			{
				OCActivity *activity = nil;

				@synchronized (_activities)
				{
					if ((activity = _activityByIdentifier[activityIdentifier]) != nil)
					{
						[activity applyUpdate:update];

						updatedActivity = activity;
					}
				}
			}
		}
		break;

		case OCActivityUpdateTypeUnpublish: {
			OCActivityIdentifier activityIdentifier = update.identifier;

			if (activityIdentifier == nil)
			{
				OCLogError(@"Unpublish-ActivityUpdate: update lacks identifer: %@", update);
			}
			else
			{
				OCActivity *unpublishedActivity = nil;

				@synchronized (_activities)
				{
					if ((unpublishedActivity = _activityByIdentifier[activityIdentifier]) != nil)
					{
						[_activityByIdentifier removeObjectForKey:activityIdentifier];
						[_activities removeObjectIdenticalTo:unpublishedActivity];

						_exposedActivities = nil;
					}
				}

				updatedActivity = unpublishedActivity;
			}
		}
		break;
	}

	if (updatedActivity != nil)
	{
		__block NSDictionary *activityUpdateDict = @{
			OCActivityManagerUpdateTypeKey : @(update.type),
			OCActivityManagerUpdateActivityKey : updatedActivity
		};

		@synchronized(_queuedActivityUpdates)
		{
			__block NSMutableIndexSet *removeUpdatesIndexes = nil;

			switch (update.type)
			{
				case OCActivityUpdateTypeUnpublish:
					// If an activity is unpublished, we can remove all previous updates regaring it
					[_queuedActivityUpdates enumerateObjectsUsingBlock:^(NSDictionary<NSString *,id<NSObject>> * _Nonnull updateDict, NSUInteger idx, BOOL * _Nonnull stop) {
						if (updateDict[OCActivityManagerUpdateActivityKey] == updatedActivity)
						{
							if (((NSNumber *)updateDict[OCActivityManagerUpdateTypeKey]).integerValue == OCActivityUpdateTypePublish)
							{
								// If the activity has not yet been published.. no need to notify about its removal now
								activityUpdateDict = nil;
							}

							if (removeUpdatesIndexes == nil)
							{
								removeUpdatesIndexes = [NSMutableIndexSet new];
							}

							[removeUpdatesIndexes addIndex:idx];
						}
					}];
				break;

				case OCActivityUpdateTypeProperty:
					// Only add property update if there's no other update (or publish) update in the queue already
					[_queuedActivityUpdates enumerateObjectsUsingBlock:^(NSDictionary<NSString *,id<NSObject>> * _Nonnull updateDict, NSUInteger idx, BOOL * _Nonnull stop) {
						if (updateDict[OCActivityManagerUpdateActivityKey] == updatedActivity)
						{
							activityUpdateDict = nil;
						}
					}];
				break;

				case OCActivityUpdateTypePublish:
					// Nothing to do here
				break;
			}

			if (removeUpdatesIndexes != nil)
			{
				[_queuedActivityUpdates removeObjectsAtIndexes:removeUpdatesIndexes];
			}

			if (activityUpdateDict != nil)
			{
				[_queuedActivityUpdates addObject:activityUpdateDict];
			}
		}

		@synchronized(_queuedActivityUpdates)
		{
			if (_queuedActivityUpdates.count > 0)
			{
				dispatch_async(dispatch_get_main_queue(), ^{
					NSDictionary *userInfo = nil;

					@synchronized(self->_queuedActivityUpdates)
					{
						if (self->_queuedActivityUpdates.count > 0)
						{
							userInfo = @{
								OCActivityManagerNotificationUserInfoUpdatesKey : [[NSArray alloc] initWithArray:self->_queuedActivityUpdates]
							};

							[self->_queuedActivityUpdates removeAllObjects];
						}
					}

					if (userInfo != nil)
					{
						[[NSNotificationCenter defaultCenter] postNotificationName:self.activityUpdateNotificationName object:nil userInfo:userInfo];
					}
				});
			}
		}
	}
}

- (nullable OCActivity *)activityForIdentifier:(OCActivityIdentifier)activityIdentifier
{
	@synchronized(_activities)
	{
		return(_activityByIdentifier[activityIdentifier]);
	}
}

#pragma mark - Log tagging
+ (nonnull NSArray<OCLogTagName> *)logTags
{
	return (@[@"ACTIVITY"]);
}

- (nonnull NSArray<OCLogTagName> *)logTags
{
	return ([[NSArray alloc] initWithObjects:@"ACTIVITY" , OCLogTagTypedID(@"ActivityNotificationName", _activityUpdateNotificationName), nil]);
}

@end

NSString *OCActivityManagerNotificationUserInfoUpdatesKey = @"updates";

NSString *OCActivityManagerUpdateTypeKey = @"updateType";
NSString *OCActivityManagerUpdateActivityKey = @"activity";
