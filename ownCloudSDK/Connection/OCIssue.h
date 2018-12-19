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

	OCIssueTypeError
};

typedef NS_ENUM(NSUInteger, OCIssueDecision)
{
	OCIssueDecisionNone,
	OCIssueDecisionReject,
	OCIssueDecisionApprove
};

typedef void(^OCIssueHandler)(OCIssue *issue, OCIssueDecision decision);

@interface OCIssue : NSObject
{
	OCIssueType _type;
	OCIssueLevel _level;

	NSString *_localizedTitle;
	NSString *_localizedDescription;

	OCCertificate *_certificate;
	OCCertificateValidationResult _certificateValidationResult;
	NSURL *_certificateURL;
	
	NSURL *_originalURL;
	NSURL *_suggestedURL;
	
	NSError *_error;
	
	BOOL _decisionMade;
	OCIssueDecision _decision;
	OCIssueHandler _issueHandler;
	
	NSArray <OCIssue *> *_issues;

	OCIssueChoice *_selectedChoice;
	NSArray <OCIssueChoice *> *_choices;
}

@property(weak) OCIssue *parentIssue;

@property(readonly) OCIssueType type;
@property(assign) OCIssueLevel level;

@property(readonly,nonatomic) BOOL resolvable;

@property(strong) NSString *localizedTitle;
@property(strong) NSString *localizedDescription;

@property(strong,readonly) OCCertificate *certificate;
@property(readonly) OCCertificateValidationResult certificateValidationResult;
@property(strong,readonly) NSURL *certificateURL;

@property(strong,readonly) NSURL *originalURL;
@property(strong,readonly) NSURL *suggestedURL;

@property(strong,readonly) NSError *error;

@property(readonly) OCIssueDecision decision;
@property(copy,readonly) OCIssueHandler issueHandler;

@property(strong,readonly) OCIssueChoice *selectedChoice;
@property(strong,readonly) NSArray <OCIssueChoice *> *choices;

@property(strong,readonly) NSArray <OCIssue *> *issues;

+ (instancetype)issueForCertificate:(OCCertificate *)certificate validationResult:(OCCertificateValidationResult)validationResult url:(NSURL *)url level:(OCIssueLevel)level issueHandler:(OCIssueHandler)issueHandler;

+ (instancetype)issueForRedirectionFromURL:(NSURL *)originalURL toSuggestedURL:(NSURL *)suggestedURL issueHandler:(OCIssueHandler)issueHandler;

+ (instancetype)issueForError:(NSError *)error level:(OCIssueLevel)level issueHandler:(OCIssueHandler)issueHandler;

+ (instancetype)issueForMultipleChoicesWithLocalizedTitle:(NSString *)localizedTitle localizedDescription:(NSString *)localizedDescription choices:(NSArray <OCIssueChoice *> *)choices completionHandler:(OCIssueHandler)issueHandler;

+ (instancetype)issueForIssues:(NSArray <OCIssue *> *)issues completionHandler:(OCIssueHandler)completionHandler;

#pragma mark - Adding issues
- (void)addIssue:(OCIssue *)issue;

#pragma mark - Decision management
- (void)approve;
- (void)reject;

#pragma mark - Multiple choice
- (void)selectChoice:(OCIssueChoice *)choice; //!< Selects the choice, calling the choice's handler and then the issueHandler with decision=OCIssueDecisionNone.
- (void)cancel; //!< Searches for a choice of type Cancel and selects it.

#pragma mark - Filtering
- (NSArray <OCIssue *> *)issuesWithLevelGreaterThanOrEqualTo:(OCIssueLevel)level;

@end

#import "OCIssueChoice.h"
