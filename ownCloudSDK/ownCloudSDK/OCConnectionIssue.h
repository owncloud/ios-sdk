//
//  OCConnectionIssue.h
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

@class OCConnectionIssue;

typedef NS_ENUM(NSUInteger, OCConnectionIssueLevel)
{
	OCConnectionIssueLevelInformal, //!< Issue that is purely informal and requires no user action
	OCConnectionIssueLevelWarning,	//!< Issue that can ultimately be resolved
	OCConnectionIssueLevelError	//!< Issue that can't be resolved
};

typedef NS_ENUM(NSUInteger, OCConnectionIssueType)
{
	OCConnectionIssueTypeGroup,	//!< This issue represents several issues, which are accessible via the issues property.

	OCConnectionIssueTypeURLRedirection,
	OCConnectionIssueTypeCertificateNeedsReview,

	OCConnectionIssueTypeError
};

typedef NS_ENUM(NSUInteger, OCConnectionIssueDecision)
{
	OCConnectionIssueDecisionNone,
	OCConnectionIssueDecisionReject,
	OCConnectionIssueDecisionApprove
};

typedef void(^OCConnectionIssueHandler)(OCConnectionIssue *issue, OCConnectionIssueDecision decision);

@interface OCConnectionIssue : NSObject
{
	OCConnectionIssueType _type;
	OCConnectionIssueLevel _level;
	
	OCCertificate *_certificate;
	OCCertificateValidationResult _certificateValidationResult;
	NSURL *_certificateURL;
	
	NSURL *_originalURL;
	NSURL *_suggestedURL;
	
	NSError *_error;
	
	BOOL _decisionMade;
	OCConnectionIssueDecision _decision;
	OCConnectionIssueHandler _issueHandler;
	
	NSArray <OCConnectionIssue *> *_issues;
}

@property(weak) OCConnectionIssue *parentIssue;

@property(readonly) OCConnectionIssueType type;
@property(assign) OCConnectionIssueLevel level;

@property(readonly,nonatomic) BOOL resolvable;

@property(strong,readonly) OCCertificate *certificate;
@property(readonly) OCCertificateValidationResult certificateValidationResult;
@property(strong,readonly) NSURL *certificateURL;

@property(strong,readonly) NSURL *originalURL;
@property(strong,readonly) NSURL *suggestedURL;

@property(strong,readonly) NSError *error;

@property(readonly) OCConnectionIssueDecision decision;
@property(copy,readonly) OCConnectionIssueHandler issueHandler;

@property(strong,readonly) NSArray <OCConnectionIssue *> *issues;

+ (instancetype)issueForCertificate:(OCCertificate *)certificate validationResult:(OCCertificateValidationResult)validationResult url:(NSURL *)url level:(OCConnectionIssueLevel)level issueHandler:(OCConnectionIssueHandler)issueHandler;

+ (instancetype)issueForRedirectionFromURL:(NSURL *)originalURL toSuggestedURL:(NSURL *)suggestedURL issueHandler:(OCConnectionIssueHandler)issueHandler;

+ (instancetype)issueForError:(NSError *)error level:(OCConnectionIssueLevel)level issueHandler:(OCConnectionIssueHandler)issueHandler;

+ (instancetype)issueForIssues:(NSArray <OCConnectionIssue *> *)issues completionHandler:(OCConnectionIssueHandler)completionHandler;

#pragma mark - Decision management
- (void)approve;
- (void)reject;

@end
