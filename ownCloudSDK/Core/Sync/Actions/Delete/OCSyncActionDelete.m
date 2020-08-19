//
//  OCSyncActionDelete.m
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

#import "OCSyncActionDelete.h"

static OCMessageTemplateIdentifier OCMessageTemplateIdentifierDeleteWithForce = @"delete.withForce";
static OCMessageTemplateIdentifier OCMessageTemplateIdentifierDeleteCancel = @"delete.cancel";

@implementation OCSyncActionDelete

OCSYNCACTION_REGISTER_ISSUETEMPLATES

+ (OCSyncActionIdentifier)identifier
{
	return(OCSyncActionIdentifierDeleteLocal);
}

+ (NSArray<OCMessageTemplate *> *)actionIssueTemplates
{
	return (@[
		// Cancel
		[OCMessageTemplate templateWithIdentifier:OCMessageTemplateIdentifierDeleteCancel categoryName:nil choices:@[
			// Drop sync record
			[OCSyncIssueChoice cancelChoiceWithImpact:OCSyncIssueChoiceImpactNonDestructive]
		] options:nil],

		// Cancel or Force Delete
		[OCMessageTemplate templateWithIdentifier:OCMessageTemplateIdentifierDeleteWithForce categoryName:nil choices:@[
			// Drop sync record
			[OCSyncIssueChoice cancelChoiceWithImpact:OCSyncIssueChoiceImpactNonDestructive],

			// Reschedule sync record with match requirement turned off
			[OCSyncIssueChoice choiceOfType:OCIssueChoiceTypeDestructive impact:OCSyncIssueChoiceImpactDataLoss identifier:@"forceDelete" label:OCLocalizedString(@"Delete",@"") metaData:nil]
		] options:nil]
	]);
}

#pragma mark - Initializer
- (instancetype)initWithItem:(OCItem *)item requireMatch:(BOOL)requireMatch
{
	if ((self = [super initWithItem:item]) != nil)
	{
		self.requireMatch = requireMatch;

		self.actionEventType = OCEventTypeDelete;
		self.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Deleting %@…"), item.name];
	}

	return (self);
}

#pragma mark - Action implementation
- (void)preflightWithContext:(OCSyncContext *)syncContext
{
	OCItem *itemToDelete;

	if ((itemToDelete = self.localItem) != nil)
	{
		// Item itself
		[itemToDelete addSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDeleting];

		syncContext.removedItems = @[ itemToDelete ];

		// Contained (associated) items
		if (itemToDelete.type == OCItemTypeCollection)
		{
			NSMutableArray <OCItem *> *removedItems = [syncContext.removedItems mutableCopy];
			NSMutableArray <OCLocalID> *removedLocalIDs = [NSMutableArray new];

			[self.core.vault.database retrieveCacheItemsRecursivelyBelowPath:itemToDelete.path includingPathItself:NO includingRemoved:NO completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, NSArray<OCItem *> *items) {
				for (OCItem *item in items)
				{
					[item addSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDeleting];

					OCLogDebug(@"Preflight: delete contained %@", OCLogPrivate(item.path));

					[removedItems addObject:item];
					[removedLocalIDs addObject:item.localID];
				}
			}];

			if (removedItems.count > 0)
			{
				syncContext.removedItems = removedItems;

				self.associatedItemLocalIDs = removedLocalIDs;
				self.associatedItemLaneTags = [self generateLaneTagsFromItems:removedItems];
			}
		}
	}
}

- (void)descheduleWithContext:(OCSyncContext *)syncContext
{
	OCItem *itemToRestore;

	if ((itemToRestore = self.localItem) != nil)
	{
		// Item itself
		[itemToRestore removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDeleting];
		if ([itemToRestore countOfSyncRecordsWithSyncActivity:OCItemSyncActivityDeleting] == 0)
		{
			itemToRestore.removed = NO;
		}

		syncContext.updatedItems = @[ itemToRestore ];

		// Contained (associated) items
		if (self.associatedItemLocalIDs.count > 0)
		{
			NSMutableArray <OCItem *> *updatedItems;

			if ((updatedItems = [syncContext.updatedItems mutableCopy]) != nil)
			{
				for (OCLocalID associatedItemLocalID in self.associatedItemLocalIDs)
				{
					[self.core.vault.database retrieveCacheItemForLocalID:associatedItemLocalID completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, OCItem *item) {
						if (item != nil)
						{
							OCLogDebug(@"Deschedule: restore delete contained %@", OCLogPrivate(item.path));

							[item removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDeleting];

							if ([item countOfSyncRecordsWithSyncActivity:OCItemSyncActivityDeleting] == 0)
							{
								item.removed = NO;
							}

							[updatedItems addObject:item];
						}
					}];
				}

				syncContext.updatedItems = updatedItems;
			}
		}
	}
}

- (OCCoreSyncInstruction)scheduleWithContext:(OCSyncContext *)syncContext
{
	OCItem *item;

	if ((item = self.archivedServerItem) != nil)
	{
		OCProgress *progress;

		if ((progress = [self.core.connection deleteItem:item requireMatch:self.requireMatch resultTarget:[self.core _eventTargetWithSyncRecord:syncContext.syncRecord]]) != nil)
		{
			[syncContext.syncRecord addProgress:progress];
		}

		// Transition to processing
		[syncContext transitionToState:OCSyncRecordStateProcessing withWaitConditions:nil];

		// Wait for result
		return (OCCoreSyncInstructionStop);
	}

	// Remove record as its action is not sufficiently specified
	return (OCCoreSyncInstructionDeleteLast);
}

- (NSError *)resolveIssue:(OCSyncIssue *)issue withChoice:(OCSyncIssueChoice *)choice context:(OCSyncContext *)syncContext
{
	NSError *resolutionError = nil;

	if ((resolutionError = [super resolveIssue:issue withChoice:choice context:syncContext]) != nil)
	{
		if (![resolutionError isOCErrorWithCode:OCErrorFeatureNotImplemented])
		{
			return (resolutionError);
		}

		if ([choice.identifier isEqual:@"forceDelete"])
		{
			// Reschedule sync record with match requirement turned off
			[self.core rescheduleSyncRecord:syncContext.syncRecord withUpdates:^NSError *(OCSyncRecord *record) {
				self.requireMatch = NO;

				return (nil);
			}];

			resolutionError = nil;
		}
	}

	return (resolutionError);
}

- (OCCoreSyncInstruction)handleResultWithContext:(OCSyncContext *)syncContext
{
	OCEvent *event = syncContext.event;
	OCSyncRecord *syncRecord = syncContext.syncRecord;
	OCSyncRecordID syncRecordID = syncContext.syncRecord.recordID;
	OCCoreSyncInstruction resultInstruction = OCCoreSyncInstructionNone;

	[syncContext completeWithError:event.error core:self.core item:self.localItem parameter:event.result];

	if ((event.error == nil) && (event.result != nil))
	{
		// Item itself
		[self.localItem removeSyncRecordID:syncRecordID activity:OCItemSyncActivityDeleting];
		syncContext.removedItems = @[ self.localItem ];

		// Contained (associated) items
		if (_associatedItemLocalIDs != nil)
		{
			NSMutableArray <OCLocalID> *remainingLocalIDs = [_associatedItemLocalIDs mutableCopy];

			NSMutableArray <OCItem *> *removedItems = [syncContext.removedItems mutableCopy];
			NSMutableArray <OCItem *> *updatedItems = [NSMutableArray new];

			// Items that are still contained in the deleted item itself
			if (self.localItem.type == OCItemTypeCollection)
			{
				[self.core.vault.database retrieveCacheItemsRecursivelyBelowPath:self.localItem.path includingPathItself:NO includingRemoved:NO completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, NSArray<OCItem *> *items) {
					for (OCItem *item in items)
					{
						OCLogDebug(@"Success: remove delete contained %@", OCLogPrivate(item.path));
						[item removeSyncRecordID:syncRecordID activity:OCItemSyncActivityDeleting];
						[removedItems addObject:item];
					}
				}];
			}

			// Items no longer contained in the deleted item itself
			for (OCLocalID associatedItemLocalID in remainingLocalIDs)
			{
				[self.core.vault.database retrieveCacheItemForLocalID:associatedItemLocalID completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, OCItem *item) {
					if (item != nil)
					{
						OCLogDebug(@"Success: restore delete contained %@", OCLogPrivate(item.path));
						[item removeSyncRecordID:syncRecordID activity:OCItemSyncActivityDeleting];

						[updatedItems addObject:item];
					}
				}];
			}

			syncContext.removedItems = removedItems;

			if (updatedItems.count > 0)
			{
				syncContext.updatedItems = updatedItems;
			}
		}

		// Remove file locally
		[self.core deleteDirectoryForItem:self.localItem];

		// Action complete and can be removed
		[syncContext transitionToState:OCSyncRecordStateCompleted withWaitConditions:nil];
		resultInstruction = OCCoreSyncInstructionDeleteLast;
	}
	else if (event.error.isOCError)
	{
		OCSyncIssue *issue = nil;
		NSString *title=nil, *description=nil;

		switch (event.error.code)
		{
			case OCErrorItemChanged:
			{
				// The item that was supposed to be deleted changed on the server => prompt user
				NSString *title = [NSString stringWithFormat:OCLocalizedString(@"%@ changed on the server. Really delete it?",nil), self.localItem.name];
				NSString *description = [NSString stringWithFormat:OCLocalizedString(@"%@ has changed on the server since you requested its deletion.",nil), self.localItem.name];

				issue = [OCSyncIssue issueFromTemplate:OCMessageTemplateIdentifierDeleteWithForce forSyncRecord:syncRecord level:OCIssueLevelError title:title description:description metaData:nil];
			}
			break;

			case OCErrorItemOperationForbidden:
				// The item that was supposed to be deleted changed on the server => prompt user
				title = [NSString stringWithFormat:OCLocalizedString(@"%@ couldn't be deleted",nil), self.localItem.path.lastPathComponent];
				description = [NSString stringWithFormat:OCLocalizedString(@"Please check if you have sufficient permissions to delete %@.",nil), self.localItem.path.lastPathComponent];
			break;

			case OCErrorItemNotFound:
				// The item that was supposed to be deleted could not be found on the server (may already have been deleted)

				// => remove item
				[self.localItem removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDeleting];
				syncContext.removedItems = @[ self.localItem ];

				// => also fetch an update of the containing dir, as the missing file could also just have been moved / renamed
				{
					NSString *parentPath = self.localItem.path.parentPath;

					if (parentPath != nil)
					{
						syncContext.refreshPaths = @[ parentPath ];
					}
				}

				OCLogDebug(@"%@ not found on the server, %@ may have been renamed, moved or deleted remotely", self.localItem.path.lastPathComponent, self.localItem.path.lastPathComponent);

				// Remove file locally
				[self.core deleteDirectoryForItem:self.localItem];

				// Action complete and can be removed
				[syncContext transitionToState:OCSyncRecordStateCompleted withWaitConditions:nil];
				resultInstruction = OCCoreSyncInstructionDeleteLast;
			break;

			default:
				// Create issue for cancellation for any other errors
				title = [NSString stringWithFormat:OCLocalizedString(@"Error deleting %@", nil), self.localItem.name];
				description = event.error.localizedDescription;
			break;
		}

		if ((issue==nil) && (title!=nil))
		{
			issue = [OCSyncIssue issueFromTemplate:OCMessageTemplateIdentifierDeleteCancel forSyncRecord:syncRecord level:OCIssueLevelError title:title description:description metaData:nil];
		}

		if (issue != nil)
		{
			[syncContext addSyncIssue:issue];
			[syncContext transitionToState:OCSyncRecordStateProcessing withWaitConditions:nil]; // updates the sync record with the issue wait condition
		}
	}
	else if (event.error != nil)
	{
		// Create issue for cancellation for all other errors
		[self _addIssueForCancellationAndDeschedulingToContext:syncContext title:[NSString stringWithFormat:OCLocalizedString(@"Couldn't delete %@", nil), self.localItem.name] description:[event.error localizedDescription] impact:OCSyncIssueChoiceImpactDataLoss]; // queues a new wait condition with the issue
		[syncContext transitionToState:OCSyncRecordStateProcessing withWaitConditions:nil]; // updates the sync record with the issue wait condition

		// Reschedule for all other errors
		/*
			// TODO: Return issue for unknown errors (other than instead of blindly rescheduling)

			https://demo.owncloud.org/remote.php/dav/files/demo/Photos/: didCompleteWithError=Error Domain=NSURLErrorDomain Code=-1009 "The Internet connection appears to be offline." UserInfo={NSUnderlyingError=0x1c4653470 {Error Domain=kCFErrorDomainCFNetwork Code=-1009 "(null)" UserInfo={_kCFStreamErrorCodeKey=50, _kCFStreamErrorDomainKey=1}}, NSErrorFailingURLStringKey=https://demo.owncloud.org/remote.php/dav/files/demo/Photos/, NSErrorFailingURLKey=https://demo.owncloud.org/remote.php/dav/files/demo/Photos/, _kCFStreamErrorDomainKey=1, _kCFStreamErrorCodeKey=50, NSLocalizedDescription=The Internet connection appears to be offline.} [OCConnectionQueue.m:506|FULL]
		*/
		// [self.core rescheduleSyncRecord:syncRecord withUpdates:nil];
	}

	return (resultInstruction);
}

#pragma mark - Lane tags
- (NSSet<OCSyncLaneTag> *)generateLaneTags
{
	NSSet<OCSyncLaneTag> *laneTags = [self generateLaneTagsFromItems:@[
		OCSyncActionWrapNullableItem(self.localItem)
	]];

	if (self.associatedItemLaneTags != nil)
	{
		laneTags = [laneTags setByAddingObjectsFromSet:self.associatedItemLaneTags];
	}

	return (laneTags);
}

#pragma mark - NSCoding
- (void)decodeActionData:(NSCoder *)decoder
{
	_requireMatch = [decoder decodeBoolForKey:@"requireMatch"];
	_associatedItemLocalIDs = [decoder decodeObjectOfClasses:[[NSSet alloc] initWithObjects:[NSArray class], [NSString class], nil] forKey:@"associatedItemLocalIDs"];
	_associatedItemLaneTags = [decoder decodeObjectOfClasses:[[NSSet alloc] initWithObjects:[NSSet class], [NSString class], nil] forKey:@"associatedItemLaneTags"];
}

- (void)encodeActionData:(NSCoder *)coder
{
	[coder encodeBool:_requireMatch forKey:@"requireMatch"];
	[coder encodeObject:_associatedItemLocalIDs forKey:@"associatedItemLocalIDs"];
	[coder encodeObject:_associatedItemLaneTags forKey:@"associatedItemLaneTags"];
}

@end
