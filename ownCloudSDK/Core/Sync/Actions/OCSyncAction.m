//
//  OCSyncAction.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.09.18.
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

#import "OCSyncAction.h"
#import "OCWaitCondition.h"
#import <objc/runtime.h>

@interface OCSyncAction ()
{
	OCItem *_localItemCached;
}
@end

@implementation OCSyncAction

#pragma mark - Class properties
+ (OCSyncActionIdentifier)identifier
{
	return (@"invalid-sync-action-identifier");
}

- (OCSyncActionIdentifier)identifier
{
	if (_identifier == nil)
	{
		return ([self.class identifier]);
	}

	return (_identifier);
}

#pragma mark - Init
- (instancetype)initWithItem:(OCItem *)item
{
	if ((self = [self init]) != nil)
	{
		_identifier = [self.class identifier];

		if (_identifier == nil)
		{
			OCLogError(@"BUG: sync action %@ has a nil +identifier", self.class);
		}

		_localItem = item;
		_archivedServerItem = ((item.remoteItem != nil) ? item.remoteItem : item);

		_localizedDescription = NSStringFromClass([self class]);
		_actionEventType = OCEventTypeNone;
		_categories = @[ OCSyncActionCategoryAll, OCSyncActionCategoryActions ];
	}

	return (self);
}

#pragma mark - Local ID
- (OCItem *)latestVersionOfLocalItem
{
	if (_localItemCached == nil)
	{
		OCSyncExec(cacheItemRetrieval, {
			[self.core.vault.database retrieveCacheItemForLocalID:self.localItem.localID completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, OCItem *item) {
				self->_localItemCached = item;

				OCSyncExecDone(cacheItemRetrieval);
			}];
		});
	}

	return ((_localItemCached != nil) ? _localItemCached : _localItem);
}

#pragma mark - Implementation
- (BOOL)implements:(SEL)featureSelector
{
	IMP rootClassIMP = method_getImplementation(class_getInstanceMethod([OCSyncAction class], featureSelector));
	IMP selfClassIMP = method_getImplementation(class_getInstanceMethod([self class], featureSelector));

	if (rootClassIMP != selfClassIMP)
	{
		return (YES);
	}

	return (NO);
}

#pragma mark - Preflight and descheduling
- (void)preflightWithContext:(OCSyncContext *)syncContext
{
}

- (void)descheduleWithContext:(OCSyncContext *)syncContext
{
}

#pragma mark - Scheduling and result handling
- (OCCoreSyncInstruction)scheduleWithContext:(OCSyncContext *)syncContext
{
	[syncContext transitionToState:OCSyncRecordStateProcessing withWaitConditions:nil];

	return (OCCoreSyncInstructionStop);
}

- (OCCoreSyncInstruction)handleResultWithContext:(OCSyncContext *)syncContext
{
	return (OCCoreSyncInstructionDeleteLast);
}

- (OCCoreSyncInstruction)handleEventWithContext:(OCSyncContext *)syncContext
{
	OCEvent *event;

	if ((event = syncContext.event) != nil)
	{
		NSUUID *waitConditionUUID;
		OCWaitCondition *waitCondition;
		BOOL handled = NO;

		// Check for wait condition
		OCWaitConditionOptions options = @{
			OCWaitConditionOptionCore : self,
			OCWaitConditionOptionSyncRecord : syncContext.syncRecord,
			OCWaitConditionOptionSyncContext : syncContext
		};

		if ((waitConditionUUID = OCTypedCast(event.userInfo[OCEventUserInfoKeyWaitConditionUUID], NSUUID)) == nil)
		{
			// If no specific wait condition was specified, see if a wait condition can handle the event
			for (OCWaitCondition *waitCondition in syncContext.syncRecord.waitConditions)
			{
				// See if wait condition can handle event
				handled = [waitCondition handleEvent:event withOptions:options sender:self];

 				if (handled) { break; }
			}
		}

		// Handle event
		if (!handled)
		{
			if (waitConditionUUID != nil)
			{
				// Pass to specific wait condition
				if ((waitCondition = [syncContext.syncRecord waitConditionForUUID:waitConditionUUID]) != nil)
				{
					[waitCondition handleEvent:event withOptions:options sender:self];
				}
			}
			else if (event.eventType != OCEventTypeWakeupSyncRecord)
			{
				// Pass to result handler
				OCCoreSyncInstruction instruction;

				instruction = [self handleResultWithContext:syncContext];

				return (instruction);
			}
		}
	}

	return (OCCoreSyncInstructionNone);
}

#pragma mark - Cancellation handling
- (OCCoreSyncInstruction)cancelWithContext:(OCSyncContext *)syncContext
{
	[self.core _descheduleSyncRecord:syncContext.syncRecord completeWithError:syncContext.error parameter:nil];

	syncContext.error = nil;

	return (OCCoreSyncInstructionProcessNext);
}

#pragma mark - Offline coalescation
- (NSError *)updatePreviousSyncRecord:(OCSyncRecord *)syncRecord context:(OCSyncContext *)syncContext
{
	return (OCError(OCErrorFeatureNotImplemented));
}

- (NSError *)updateActionWith:(OCItem *(^)(OCSyncContext *syncContext, OCSyncAction *syncAction, OCItem *item))actionUpdater context:(OCSyncContext *)syncContext
{
	return (OCError(OCErrorFeatureNotImplemented));
}

#pragma mark - Wait condition failure handling
- (BOOL)recoverFromWaitCondition:(OCWaitCondition *)waitCondition failedWithError:(NSError *)error context:(OCSyncContext *)syncContext
{
	return (NO);
}

#pragma mark - Issue generation
+ (NSArray<OCMessageTemplate *> *)issueTemplates
{
	NSMutableArray<OCMessageTemplate *> *templates = [NSMutableArray new];
	OCSyncActionIdentifier actionIdentifier;

	// Standard templates
	if ((actionIdentifier = self.identifier) != nil)
	{
		// Standard cancellation template used by _addIssueForCancellationAndDeschedulingToContext:
		[templates addObject:[OCMessageTemplate templateWithIdentifier:[actionIdentifier stringByAppendingString:@"._cancel.dataLoss"] categoryName:nil choices:@[
			[OCSyncIssueChoice cancelChoiceWithImpact:OCSyncIssueChoiceImpactDataLoss]
		] options:nil]];

		[templates addObject:[OCMessageTemplate templateWithIdentifier:[actionIdentifier stringByAppendingString:@"._cancel.nonDestructive"] categoryName:nil choices:@[
			[OCSyncIssueChoice cancelChoiceWithImpact:OCSyncIssueChoiceImpactNonDestructive]
		] options:nil]];
	}

	// Action-specific templates
	NSArray<OCMessageTemplate *> *actionIssueTemplates;

	if ((actionIssueTemplates = self.actionIssueTemplates) != nil)
	{
		[templates addObjectsFromArray:actionIssueTemplates];
	}

	return (templates);
}

+ (NSArray<OCMessageTemplate *> *)actionIssueTemplates
{
	return (nil);
}

- (OCSyncIssue *)_addIssueForCancellationAndDeschedulingToContext:(OCSyncContext *)syncContext title:(NSString *)title description:(NSString *)description impact:(OCSyncIssueChoiceImpact)impact
{
	OCSyncIssue *issue;
	OCSyncRecord *syncRecord = syncContext.syncRecord;

	issue = [OCSyncIssue issueFromTemplate:[self.identifier stringByAppendingString:((impact == OCSyncIssueChoiceImpactDataLoss) ? @"._cancel.dataLoss" : @"._cancel.nonDestructive")] forSyncRecord:syncRecord level:OCIssueLevelError title:title description:description metaData:nil];

	[syncContext addSyncIssue:issue];

	return (issue);
}

#pragma mark - Issue handling
- (nullable NSError *)resolveIssue:(OCSyncIssue *)issue withChoice:(OCSyncIssueChoice *)choice context:(OCSyncContext *)syncContext
{
	if ([choice.identifier isEqual:OCSyncIssueChoiceIdentifierRetry])
	{
		[_core rescheduleSyncRecord:syncContext.syncRecord withUpdates:nil];

		return (nil);
	}

	if ([choice.identifier isEqual:OCSyncIssueChoiceIdentifierCancel])
	{
		[_core descheduleSyncRecord:syncContext.syncRecord completeWithError:OCError(OCErrorCancelled) parameter:nil];

		return (nil);
	}

	return (OCError(OCErrorFeatureNotImplemented));
}

#pragma mark - Properties
- (NSData *)_archivedServerItemData
{
	if ((_archivedServerItemData == nil) && (_archivedServerItem != nil))
	{
		_archivedServerItemData = [NSKeyedArchiver archivedDataWithRootObject:_archivedServerItem];
	}

	return (_archivedServerItemData);
}

- (OCItem *)archivedServerItem
{
	if ((_archivedServerItem == nil) && (_archivedServerItemData != nil))
	{
		_archivedServerItem = [NSKeyedUnarchiver unarchiveObjectWithData:_archivedServerItemData];
	}

	return (_archivedServerItem);
}

#pragma mark - Restore progress
- (OCItem *)itemToRestoreProgressRegistrationFor
{
	return (nil);
}

- (void)restoreProgressRegistrationForSyncRecord:(OCSyncRecord *)syncRecord
{
	NSProgress *progress = nil;
	OCItem *item;

	if ((item = [self itemToRestoreProgressRegistrationFor]) != nil)
	{
		if ((progress = [syncRecord.progress resolveWith:nil]) != nil)
		{
			[self.core registerProgress:progress forItem:item];
		}
	}
}

#pragma mark - Lane tags
- (NSSet<OCSyncLaneTag> *)laneTags
{
	if (_laneTags == nil)
	{
		_laneTags = [self generateLaneTags];
	}

	return (_laneTags);
}

- (NSSet <OCSyncLaneTag> *)generateLaneTags
{
	return ([NSSet new]);
}

- (NSMutableSet <OCSyncLaneTag> *)generateLaneTagsFromItems:(NSArray<OCItem *> *)items
{
	NSMutableSet<OCSyncLaneTag> *laneTags = [NSMutableSet new];

	for (OCItem *item in items)
	{
		if ([item isKindOfClass:[OCItem class]])
		{
			if (item.localID != nil)
			{
				[laneTags addObject:item.localID];
			}

			if (item.path != nil)
			{
				[laneTags addObject:item.path];
			}
		}
	}

	return (laneTags);
}

#pragma mark - NSSecureCoding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_identifier forKey:@"identifier"];

	[coder encodeObject:_localItem forKey:@"localItem"];

	[coder encodeObject:[self _archivedServerItemData] forKey:@"archivedServerItemData"];
	[coder encodeObject:_parameters forKey:@"parameters"];

	[coder encodeObject:_laneTags forKey:@"laneTags"];

	[coder encodeObject:_localizedDescription forKey:@"localizedDescription"];
	[coder encodeInteger:_actionEventType forKey:@"actionEventType"];
	[coder encodeObject:_categories forKey:@"categories"];

	[self encodeActionData:coder];
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [self init]) != nil)
	{
		_identifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"identifier"];

		_localItem = [decoder decodeObjectOfClass:[OCItem class] forKey:@"localItem"];

		_archivedServerItemData = [decoder decodeObjectOfClass:[NSData class] forKey:@"archivedServerItemData"];
		_parameters = [decoder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"parameters"];

		_laneTags = [decoder decodeObjectOfClasses:[[NSSet alloc] initWithObjects:[NSSet class], [NSString class], nil] forKey:@"laneTags"];

		_localizedDescription = [decoder decodeObjectOfClass:[NSString class] forKey:@"localizedDescription"];
		_actionEventType = [decoder decodeIntegerForKey:@"actionEventType"];
		_categories = [decoder decodeObjectOfClasses:[[NSSet alloc] initWithObjects:[NSArray class], [NSString class], nil] forKey:@"categories"];

		[self decodeActionData:decoder];
	}

	return (self);
}

- (void)encodeActionData:(NSCoder *)coder
{
}

- (void)decodeActionData:(NSCoder *)decoder
{
}

#pragma mark - Log tags
+ (NSArray<OCLogTagName> *)logTags
{
	return (@[@"SyncAction"]);
}

- (NSArray<OCLogTagName> *)logTags
{
	return (@[@"SyncAction", [NSStringFromClass([self class]) substringFromIndex:12]]);
}

#pragma mark - Description
- (NSString *)description
{
	NSString *internals = self.internalsDescription;

	return ([NSString stringWithFormat:@"<%@: %p, identifier: %@%@, description: %@>", NSStringFromClass(self.class), self, _identifier, ((internals != nil) ? [NSString stringWithFormat:@", %@", internals] : @""), self.localizedDescription]);
}

- (NSString *)privacyMaskedDescription
{
	return ([NSString stringWithFormat:@"<%@: %p, identifier: %@, description: %@>", NSStringFromClass(self.class), self, _identifier, OCLogPrivate(self.localizedDescription)]);
}

- (NSString *)internalsDescription
{
	return (nil);
}

@end

OCSyncActionCategory OCSyncActionCategoryAll = @"all";
OCSyncActionCategory OCSyncActionCategoryActions = @"actions";
OCSyncActionCategory OCSyncActionCategoryTransfer = @"transfer";
