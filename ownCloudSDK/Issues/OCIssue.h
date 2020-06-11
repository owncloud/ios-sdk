//
//  OCIssue.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 01.03.18.
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

#import <Foundation/Foundation.h>
#import "OCCertificate.h"

@class OCIssue;
@class OCIssueChoice;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, OCIssueLevel)
{
	OCIssueLevelInformal, //!< Issue that is purely informal and requires no user action
	OCIssueLevelWarning,	//!< Issue that can ultimately be resolved, but for which the user should be prompted
	OCIssueLevelError	//!< Issue that can't be resolved
};

typedef NS_ENUM(NSUInteger, OCIssueType)
{
	OCIssueTypeGroup,	//!< This issue represents several issues, which are accessible via the issues property.
	OCIssueTypeMultipleChoice, //!< This issue provides the user with multiple choices to pick from.

	OCIssueTypeURLRedirection,
	OCIssueTypeCertificate,
	OCIssueTypeGeneric,

	OCIssueTypeError
};

typedef NS_ENUM(NSUInteger, OCIssueDecision)
{
	OCIssueDecisionNone,
	OCIssueDecisionReject,
	OCIssueDecisionApprove
};

typedef void(^OCIssueHandler)(OCIssue *issue, OCIssueDecision decision);

typedef NSString* OCIssueSignature; //!< Signature that - for identical issues - will be identical

@interface OCIssue : NSObject

@property(weak) OCIssue *parentIssue;

@property(readonly) OCIssueType type;
@property(assign) OCIssueLevel level;

@property(readonly,nonatomic) BOOL resolvable;

@property(nullable,strong) NSUUID *uuid; //!< Equal to OCSyncIssueUUID if generated from an OCSyncIssue

@property(nullable,strong) NSString *localizedTitle;
@property(nullable,strong) NSString *localizedDescription;

@property(nullable,strong,readonly) OCCertificate *certificate;
@property(readonly) OCCertificateValidationResult certificateValidationResult;
@property(nullable,strong,readonly) NSURL *certificateURL;

@property(nullable,strong,readonly) NSURL *originalURL;
@property(nullable,strong,readonly) NSURL *suggestedURL;

@property(nullable,strong,readonly) NSError *error;

@property(readonly) OCIssueDecision decision;
@property(nullable,copy,readonly) OCIssueHandler issueHandler;

@property(nullable,strong,readonly) OCIssueChoice *selectedChoice;
@property(nullable,strong,readonly) NSArray <OCIssueChoice *> *choices;

@property(nullable,strong,readonly) NSArray <OCIssue *> *issues;

@property(nullable,strong,readonly) OCIssueSignature signature;

+ (instancetype)issueForCertificate:(OCCertificate *)certificate validationResult:(OCCertificateValidationResult)validationResult url:(NSURL *)url level:(OCIssueLevel)level issueHandler:(nullable OCIssueHandler)issueHandler;

+ (instancetype)issueForRedirectionFromURL:(NSURL *)originalURL toSuggestedURL:(NSURL *)suggestedURL issueHandler:(nullable OCIssueHandler)issueHandler;

+ (instancetype)issueForError:(NSError *)error level:(OCIssueLevel)level issueHandler:(nullable OCIssueHandler)issueHandler;

+ (instancetype)issueForMultipleChoicesWithLocalizedTitle:(NSString *)localizedTitle localizedDescription:(NSString *)localizedDescription choices:(NSArray <OCIssueChoice *> *)choices completionHandler:(nullable OCIssueHandler)issueHandler;

+ (instancetype)issueWithLocalizedTitle:(NSString *)title localizedDescription:(NSString *)localizedDescription level:(OCIssueLevel)level issueHandler:(nullable OCIssueHandler)issueHandler;

+ (instancetype)issueForIssues:(NSArray <OCIssue *> *)issues completionHandler:(nullable OCIssueHandler)completionHandler;

#pragma mark - Adding issues
- (void)addIssue:(OCIssue *)issue;

#pragma mark - Decision management
- (void)approve;
- (void)reject;

#pragma mark - Multiple choice
- (void)selectChoice:(OCIssueChoice *)choice; //!< Selects the choice, calling the choice's handler and then the issueHandler with decision=OCIssueDecisionNone.
- (void)cancel; //!< Searches for a choice of type Cancel and selects it.

#pragma mark - Filtering
- (nullable NSArray <OCIssue *> *)issuesWithLevelGreaterThanOrEqualTo:(OCIssueLevel)level;

#pragma mark - Handling
- (void)appendIssueHandler:(OCIssueHandler)issueHandler;

@end

NS_ASSUME_NONNULL_END

#import "OCIssueChoice.h"
