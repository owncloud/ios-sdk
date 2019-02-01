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

@implementation OCSyncAction

#pragma mark - Init
- (instancetype)initWithItem:(OCItem *)item
{
	if ((self = [self init]) != nil)
	{
		_localItem = item;
		_archivedServerItem = ((item.remoteItem != nil) ? item.remoteItem : item);

		_localizedDescription = NSStringFromClass([self class]);
		_actionEventType = OCEventTypeNone;
	}

	return (self);
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
			else
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

	[coder encodeObject:_localizedDescription forKey:@"localizedDescription"];

	[self encodeActionData:coder];
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [self init]) != nil)
	{
		_identifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"identifier"];

		_localItem = [decoder decodeObjectOfClass:[OCItem class] forKey:@"localItem"];
		_archivedServerItemData = [decoder decodeObjectOfClass:[NSData class] forKey:@"archivedServerItemData"];

		_parameters = [decoder decodeObjectOfClass:[NSDictionary class] forKey:@"parameters"];

		_localizedDescription = [decoder decodeObjectOfClass:[NSString class] forKey:@"localizedDescription"];

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
	return ([NSString stringWithFormat:@"<%@: %p, identifier: %@, description: %@>", NSStringFromClass(self.class), self, _identifier, self.localizedDescription]);
}

- (NSString *)privacyMaskedDescription
{
	return ([NSString stringWithFormat:@"<%@: %p, identifier: %@, description: %@>", NSStringFromClass(self.class), self, _identifier, OCLogPrivate(self.localizedDescription)]);
}

@end
