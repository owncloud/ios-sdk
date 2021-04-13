//
//  OCMessage.h
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

#import <Foundation/Foundation.h>
#import "OCProcessSession.h"
#import "OCAppIdentity.h"
#import "OCMessagePresenter.h"
#import "OCBookmark.h"
#import "OCMessageChoice.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSUUID* OCMessageUUID;

@class OCCore;
@class OCSyncIssue;

typedef NSString* OCMessageOriginIdentifier NS_TYPED_ENUM;

typedef NSString* OCMessageCategoryIdentifier NS_TYPED_ENUM;
typedef NSString* OCMessageThreadIdentifier;

@interface OCMessage : NSObject <NSSecureCoding>

#pragma mark - ID & Metadata
@property(strong,readonly,nullable) OCMessageOriginIdentifier originIdentifier; //!< Optional identifier uniquely identifying the part the message originated from (i.e. sync engine, ..)
@property(strong,readonly) NSDate *date; //!< Date the record was created
@property(strong,nonatomic,readonly) OCMessageUUID uuid; //!< UUID of this record (identical to syncIssue.uuid for sync issues)

@property(strong,nonatomic,nullable) OCMessageCategoryIdentifier categoryIdentifier; //!< Identifier used to categorize the message
@property(strong,nonatomic,nullable) OCMessageThreadIdentifier threadIdentifier; //!< Identifier used to assign a message to a thread

#pragma mark - Bookmark reference
@property(strong,nonatomic,nullable) OCBookmarkUUID bookmarkUUID; //!< UUID of the bookmark that this message belongs to (nil for global issues)

#pragma mark - Sync issue integration
@property(strong,nullable) OCSyncIssue *syncIssue; //!< The sync issue represented by this message

#pragma mark - Represented object
@property(strong,nullable) id<NSSecureCoding> representedObject; //!< Object represented by this message, choice limited to objects from OCEvent.safeClasses. Use this to store metadata/objects you need to handle the message choice.

#pragma mark - Unified content access
@property(readonly,nonatomic,nullable) NSString *localizedTitle;
@property(readonly,nonatomic,nullable) NSString *localizedDescription;

#pragma mark - Choics
@property(readonly,nonatomic,nullable) NSArray<OCMessageChoice *> *choices;

- (nullable OCMessageChoice *)choiceWithIdentifier:(OCMessageChoiceIdentifier)choiceIdentifier;

@property(strong,nullable) OCMessageChoice *pickedChoice; //!< The choice picked by the user for the message

#pragma mark - Presentation
@property(strong,nullable) NSSet<OCMessagePresenterComponentSpecificIdentifier> *processedBy; //!< component-specific identifiers of presenters that have already processed this issue (used to avoids duplicate handling and infinite loops)
@property(strong,nullable) OCProcessSession *lockingProcess; //!< process session of the process currently locking the record. Check for validity to determine if the lock is still valid. If it is valid, do not process this record.

@property(assign) BOOL presentedToUser; //!< Indicator if the message has previously been presented to the user

@property(strong,nullable) OCMessagePresenterIdentifier presentationPresenterIdentifier; //!< The identifier of the presenter that presented the message to the user
@property(strong,nullable) OCAppComponentIdentifier presentationAppComponentIdentifier; //!< The identifier of the app component from which the presentation originated. Only set this if the presentation end notification needs to be delivered in this exact app component.
@property(assign) BOOL presentationRequiresEndNotification; //!< YES if the presenter requires a call to -[OCMessagePresenter endPresentationOfMessage:] before the message is removed from the queue.

#pragma mark - Handling
@property(assign) BOOL removed; //!< YES if the message should be considered removed, and be removed as soon as .presentationRequiresEndNotification has been honored.

@property(nonatomic,readonly) BOOL resolved; //!< Indicator if the message has already been resolved (automatically, or through user interaction)
@property(nonatomic,readonly) BOOL autoRemove; //!< Indicator if the message should be auto-removed once it was resolved

#pragma mark - Creation
- (instancetype)initWithSyncIssue:(OCSyncIssue *)syncIssue fromCore:(OCCore *)core; //!< Create a message from a sync issue (primarily used internally by the SDK)

- (instancetype)initWithOrigin:(OCMessageOriginIdentifier)originIdentifier bookmarkUUID:(OCBookmarkUUID)bookmarkUUID date:(nullable NSDate *)date uuid:(nullable NSUUID *)uuid title:(NSString *)localizedTitle description:(nullable NSString *)localizedDescription choices:(NSArray<OCMessageChoice *> *)choices;

- (instancetype)initWithOrigin:(OCMessageOriginIdentifier)originIdentifier bookmarkUUID:(OCBookmarkUUID)bookmarkUUID title:(NSString *)localizedTitle description:(nullable NSString *)localizedDescription choices:(NSArray<OCMessageChoice *> *)choices;

#pragma mark - Mute
- (void)mute; //!< When used on creation, mutes a message so it is not presented to the user

@end

extern OCMessageOriginIdentifier OCMessageOriginIdentifierSyncEngine; //!< Message origin is the sync engine
extern OCMessageOriginIdentifier OCMessageOriginIdentifierDynamic; //!< Message origin is a dynamic piece of code that can't handle the response

NS_ASSUME_NONNULL_END

#import "OCSyncIssue.h"
