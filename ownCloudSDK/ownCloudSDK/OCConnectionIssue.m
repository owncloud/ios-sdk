//
//  OCConnectionIssue.m
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

#import "OCConnectionIssue.h"

@interface OCConnectionIssue ()
{
	BOOL _ignoreChildEvents;
}
@end

@implementation OCConnectionIssue

@synthesize type = _type;
@synthesize level = _level;

@synthesize certificate = _certificate;
@synthesize certificateValidationResult = _certificateValidationResult;
@synthesize certificateURL = _certificateURL;

@synthesize originalURL = _originalURL;
@synthesize suggestedURL = _suggestedURL;

@synthesize decision = _decision;
@synthesize issueHandler = _issueHandler;

@synthesize issues = _issues;

#pragma mark - Init
+ (instancetype)issueForCertificate:(OCCertificate *)certificate validationResult:(OCCertificateValidationResult)validationResult url:(NSURL *)url level:(OCConnectionIssueLevel)level issueHandler:(OCConnectionIssueHandler)issueHandler
{
	return ([[self alloc] initWithCertificate:certificate validationResult:validationResult url:url level:level issueHandler:issueHandler]);
}

+ (instancetype)issueForRedirectionFromURL:(NSURL *)originalURL toSuggestedURL:(NSURL *)suggestedURL issueHandler:(OCConnectionIssueHandler)issueHandler
{
	return ([[self alloc] initWithRedirectionFromURL:originalURL toSuggestedURL:suggestedURL issueHandler:issueHandler]);
}

+ (instancetype)issueForIssues:(NSArray <OCConnectionIssue *> *)issues completionHandler:(OCConnectionIssueHandler)completionHandler
{
	return ([[self alloc] initWithIssues:issues completionHandler:completionHandler]);
}

+ (instancetype)issueForError:(NSError *)error level:(OCConnectionIssueLevel)level issueHandler:(OCConnectionIssueHandler)issueHandler
{
	return ([[self alloc] initWithError:error level:level issueHandler:issueHandler]);
}

- (instancetype)initWithCertificate:(OCCertificate *)certificate validationResult:(OCCertificateValidationResult)validationResult url:(NSURL *)url level:(OCConnectionIssueLevel)level issueHandler:(OCConnectionIssueHandler)issueHandler
{
	if ((self = [super init]) != nil)
	{
		_type = OCConnectionIssueTypeCertificateNeedsReview;
		_level = level;
	
		_certificate = certificate;
		_certificateValidationResult = validationResult;
		_certificateURL = url;
		
		_issueHandler = [issueHandler copy];
	}
	
	return(self);
}

- (instancetype)initWithRedirectionFromURL:(NSURL *)originalURL toSuggestedURL:(NSURL *)suggestedURL issueHandler:(OCConnectionIssueHandler)issueHandler
{
	if ((self = [super init]) != nil)
	{
		_type = OCConnectionIssueTypeURLRedirection;
		_level = OCConnectionIssueLevelWarning;

		_originalURL = originalURL;
		_suggestedURL = suggestedURL;

		_issueHandler = [issueHandler copy];
	}
	
	return(self);
}

- (instancetype)initWithError:(NSError *)error level:(OCConnectionIssueLevel)level issueHandler:(OCConnectionIssueHandler)issueHandler
{
	if ((self = [super init]) != nil)
	{
		_type = OCConnectionIssueTypeError;
		_level = level;
		
		_error = error;

		_issueHandler = [issueHandler copy];
	}
	
	return(self);
}

- (instancetype)initWithIssues:(NSArray <OCConnectionIssue *> *)issues completionHandler:(OCConnectionIssueHandler)completionHandler
{
	if ((self = [super init]) != nil)
	{
		OCConnectionIssueLevel highestLevel = OCConnectionIssueLevelWarning;
	
		_type = OCConnectionIssueTypeGroup;

		_issues = issues;
		_issueHandler = [completionHandler copy];
		
		for (OCConnectionIssue *issue in issues)
		{
			issue.parentIssue = self;
			
			if (issue.level > highestLevel)
			{
				highestLevel = issue.level;
			}
		}
		
		_level = highestLevel;
	}
	
	return(self);
}

#pragma mark - Accessors
- (BOOL)resolvable
{
	return (_level != OCConnectionIssueLevelError);
}

#pragma mark - Decision management
- (void)_childIssueMadeDecision:(OCConnectionIssue *)childIssue
{
	if (!_ignoreChildEvents)
	{
		NSUInteger decisionCounts[3] = { 0, 0, 0 };

		for (OCConnectionIssue *issue in _issues)
		{
			if (issue.decision < 3)
			{
				decisionCounts[issue.decision]++;
			}
		}
		
		if (decisionCounts[OCConnectionIssueDecisionNone] == 0)
		{
			OCConnectionIssueDecision summaryDecision = OCConnectionIssueDecisionNone;
		
			if (decisionCounts[OCConnectionIssueDecisionApprove] == _issues.count)
			{
				summaryDecision = OCConnectionIssueDecisionApprove;
			}
			else if (decisionCounts[OCConnectionIssueDecisionReject] == _issues.count)
			{
				summaryDecision = OCConnectionIssueDecisionReject;
			}

			[self _madeDecision:summaryDecision];
		}
	}
}

- (void)_madeDecision:(OCConnectionIssueDecision)decision
{
	BOOL madeDecision = NO;

	@synchronized(self)
	{
		if (!_decisionMade)
		{
			_decisionMade = YES;
			_decision = decision;
			madeDecision = YES;
		}
	}
	
	if (madeDecision)
	{
		if (_type == OCConnectionIssueTypeGroup)
		{
			_ignoreChildEvents = YES;

			for (OCConnectionIssue *issue in _issues)
			{
				[issue _madeDecision:decision];
			}

			_ignoreChildEvents = NO;
		}

		if (_issueHandler != nil)
		{
			_issueHandler(self, decision);
		}

		if (_parentIssue != nil)
		{
			[_parentIssue _childIssueMadeDecision:self];
		}
	}
}

- (void)approve
{
	[self _madeDecision:OCConnectionIssueDecisionApprove];
}

- (void)reject
{
	[self _madeDecision:OCConnectionIssueDecisionReject];
}

- (NSString *)description
{
	NSMutableString *descriptionString = [NSMutableString stringWithFormat:@"<%@: 0x%p, type: ", NSStringFromClass([self class]), self];

	switch (_type)
	{
		
		case OCConnectionIssueTypeGroup:
			[descriptionString appendFormat:@"Group [%@]", _issues];
		break;

		case OCConnectionIssueTypeURLRedirection:
			[descriptionString appendFormat:@"Redirection [%@ -> %@]", _originalURL, _suggestedURL];
		break;

		case OCConnectionIssueTypeCertificateNeedsReview:
			[descriptionString appendFormat:@"Certificate [%@]", _certificate.hostName];
		break;

		case OCConnectionIssueTypeError:
			[descriptionString appendFormat:@"Error [%@]", _error];
		break;
	}

	[descriptionString appendString:@">"];

	return (descriptionString);
}

@end
