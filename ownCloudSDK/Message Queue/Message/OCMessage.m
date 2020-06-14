//
//  OCMessage.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 17.02.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCMessage.h"
#import "OCCore.h"

@interface OCMessage ()
{
	NSString *_localizedTitle;
	NSString *_localizedDescription;
	NSArray<OCMessageChoice *> *_choices;
}
@end

@implementation OCMessage

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_date = [NSDate new];
		_uuid = [NSUUID new];
	}

	return (self);
}

- (instancetype)initWithSyncIssue:(OCSyncIssue *)syncIssue fromCore:(OCCore *)core
{
	if ((self = [super init]) != nil)
	{
		_originIdentifier = OCMessageOriginIdentifierSyncEngine;

		_date = syncIssue.creationDate;
		_uuid = syncIssue.uuid;

		_categoryIdentifier = syncIssue.templateIdentifier;

		_syncIssue = syncIssue;
		_bookmarkUUID = core.bookmark.uuid;
	}

	return (self);
}


- (instancetype)initWithOrigin:(OCMessageOriginIdentifier)originIdentifier bookmarkUUID:(OCBookmarkUUID)bookmarkUUID date:(nullable NSDate *)date uuid:(nullable NSUUID *)uuid title:(NSString *)localizedTitle description:(nullable NSString *)localizedDescription choices:(NSArray<OCMessageChoice *> *)choices
{
	if ((self = [super init]) != nil)
	{
		_originIdentifier = originIdentifier;
		_bookmarkUUID = bookmarkUUID;

		_date = (date != nil) ? date : [NSDate new];
		_uuid = (uuid != nil) ? uuid : NSUUID.UUID;

		_localizedTitle = localizedTitle;
		_localizedDescription = localizedDescription;

		_choices = choices;
	}

	return (self);
}

- (instancetype)initWithOrigin:(OCMessageOriginIdentifier)originIdentifier bookmarkUUID:(OCBookmarkUUID)bookmarkUUID title:(NSString *)localizedTitle description:(nullable NSString *)localizedDescription choices:(NSArray<OCMessageChoice *> *)choices
{
	return ([self initWithOrigin:originIdentifier bookmarkUUID:bookmarkUUID date:nil uuid:nil title:localizedTitle description:localizedDescription choices:choices]);
}

- (BOOL)resolved
{
	return (_pickedChoice != nil);
}

- (BOOL)autoRemove
{
	return ((_originIdentifier != nil) && [_originIdentifier isEqual:OCMessageOriginIdentifierDynamic]);
}

#pragma mark - Unified content access
- (NSString *)localizedTitle
{
	if (_syncIssue != nil)
	{
		return (_syncIssue.localizedTitle);
	}

	return (_localizedTitle);
}

- (NSString *)localizedDescription
{
	if (_syncIssue != nil)
	{
		return (_syncIssue.localizedDescription);
	}

	return (_localizedDescription);
}

#pragma mark - Choices
- (NSArray<OCMessageChoice *> *)choices
{
	if (_syncIssue != nil)
	{
		return (_syncIssue.choices);
	}

	return (_choices);
}

- (nullable OCMessageChoice *)choiceWithIdentifier:(OCMessageChoiceIdentifier)choiceIdentifier;
{
	for (OCMessageChoice *choice in self.choices)
	{
		if ([choice.identifier isEqual:choiceIdentifier])
		{
			return (choice);
		}
	}

	return (nil);
}

#pragma mark - En-/Decoding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [self init]) != nil)
	{
		_originIdentifier = [decoder decodeObjectOfClass:NSString.class forKey:@"originIdentifier"];

		_date = [decoder decodeObjectOfClass:NSDate.class forKey:@"date"];
		_uuid = [decoder decodeObjectOfClass:NSUUID.class forKey:@"uuid"];

		_categoryIdentifier = [decoder decodeObjectOfClass:NSString.class forKey:@"categoryIdentifier"];
		_threadIdentifier = [decoder decodeObjectOfClass:NSString.class forKey:@"threadIdentifier"];

		_bookmarkUUID = [decoder decodeObjectOfClass:NSUUID.class forKey:@"bookmarkUUID"];

		_syncIssue = [decoder decodeObjectOfClass:OCSyncIssue.class forKey:@"syncIssue"];

		_representedObject = [decoder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"representedObject"];

		_localizedTitle = [decoder decodeObjectOfClass:NSString.class forKey:@"localizedTitle"];
		_localizedDescription = [decoder decodeObjectOfClass:NSString.class forKey:@"localizedDescription"];
		_choices = [decoder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"choices"];

		_pickedChoice = [decoder decodeObjectOfClass:OCMessageChoice.class forKey:@"pickedChoice"];

		_processedBy = [decoder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"processedBy"];
		_lockingProcess = [decoder decodeObjectOfClass:OCProcessSession.class forKey:@"lockingProcess"];

		_presentedToUser = [decoder decodeBoolForKey:@"presentedToUser"];

		_presentationPresenterIdentifier = [decoder decodeObjectOfClass:NSString.class forKey:@"presentationPresenterIdentifier"];
		_presentationAppComponentIdentifier = [decoder decodeObjectOfClass:NSString.class forKey:@"presentationAppComponentIdentifier"];

		_presentationRequiresEndNotification = [decoder decodeBoolForKey:@"presentationRequiresEndNotification"];

		_removed = [decoder decodeBoolForKey:@"removed"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_originIdentifier forKey:@"originIdentifier"];

	[coder encodeObject:_date forKey:@"date"];
	[coder encodeObject:_uuid forKey:@"uuid"];

	[coder encodeObject:_categoryIdentifier forKey:@"categoryIdentifier"];
	[coder encodeObject:_threadIdentifier forKey:@"threadIdentifier"];

	[coder encodeObject:_bookmarkUUID forKey:@"bookmarkUUID"];

	[coder encodeObject:_syncIssue forKey:@"syncIssue"];

	[coder encodeObject:_representedObject forKey:@"representedObject"];

	[coder encodeObject:_localizedTitle forKey:@"localizedTitle"];
	[coder encodeObject:_localizedDescription forKey:@"localizedDescription"];
	[coder encodeObject:_choices forKey:@"choices"];

	[coder encodeObject:_pickedChoice forKey:@"pickedChoice"];

	[coder encodeObject:_processedBy forKey:@"processedBy"];
	[coder encodeObject:_lockingProcess forKey:@"lockingProcess"];

	[coder encodeBool:_presentedToUser forKey:@"presentedToUser"];

	[coder encodeObject:_presentationPresenterIdentifier forKey:@"presentationPresenterIdentifier"];
	[coder encodeObject:_presentationAppComponentIdentifier forKey:@"presentationAppComponentIdentifier"];

	[coder encodeBool:_presentationRequiresEndNotification forKey:@"presentationRequiresEndNotification"];

	[coder encodeBool:_removed forKey:@"removed"];
}

@end

OCMessageOriginIdentifier OCMessageOriginIdentifierSyncEngine = @"sync-engine";
OCMessageOriginIdentifier OCMessageOriginIdentifierDynamic = @"dynamic";

