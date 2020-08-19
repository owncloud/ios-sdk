//
//  OCIssue.m
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

#import "OCIssue.h"
#import "OCMacros.h"
#import "NSURL+OCURLQueryParameterExtensions.h"
#import "OCIssueChoice.h"

@interface OCIssue ()
{
	BOOL _decisionMade;
	BOOL _ignoreChildEvents;
}
@end

@implementation OCIssue

#pragma mark - Init
+ (instancetype)issueForCertificate:(OCCertificate *)certificate validationResult:(OCCertificateValidationResult)validationResult url:(NSURL *)url level:(OCIssueLevel)level issueHandler:(OCIssueHandler)issueHandler
{
	return ([[self alloc] initWithCertificate:certificate validationResult:validationResult url:url level:level issueHandler:issueHandler]);
}

+ (instancetype)issueForRedirectionFromURL:(NSURL *)originalURL toSuggestedURL:(NSURL *)suggestedURL issueHandler:(OCIssueHandler)issueHandler
{
	return ([[self alloc] initWithRedirectionFromURL:originalURL toSuggestedURL:suggestedURL issueHandler:issueHandler]);
}

+ (instancetype)issueForMultipleChoicesWithLocalizedTitle:(NSString *)localizedTitle localizedDescription:(NSString *)localizedDescription choices:(NSArray <OCIssueChoice *> *)choices completionHandler:(OCIssueHandler)issueHandler
{
	return ([[self alloc] initMultipleChoicesWithLocalizedTitle:localizedTitle localizedDescription:localizedDescription choices:choices completionHandler:issueHandler]);
}

+ (instancetype)issueForIssues:(NSArray <OCIssue *> *)issues completionHandler:(OCIssueHandler)completionHandler
{
	return ([[self alloc] initWithIssues:issues completionHandler:completionHandler]);
}

+ (instancetype)issueForError:(NSError *)error level:(OCIssueLevel)level issueHandler:(OCIssueHandler)issueHandler
{
	return ([[self alloc] initWithError:error level:level issueHandler:issueHandler]);
}

+ (instancetype)issueWithLocalizedTitle:(NSString *)localizedTitle localizedDescription:(NSString *)localizedDescription level:(OCIssueLevel)level issueHandler:(nullable OCIssueHandler)issueHandler
{
	return ([[self alloc] initWithLocalizedTitle:localizedTitle localizedDescription:localizedDescription level:level issueHandler:issueHandler]);
}

- (instancetype)initWithCertificate:(OCCertificate *)certificate validationResult:(OCCertificateValidationResult)validationResult url:(NSURL *)url level:(OCIssueLevel)level issueHandler:(OCIssueHandler)issueHandler
{
	if ((self = [super init]) != nil)
	{
		_type = OCIssueTypeCertificate;
		_level = level;

		_certificate = certificate;
		_certificateValidationResult = validationResult;
		_certificateURL = url;

		_issueHandler = [issueHandler copy];

		_localizedTitle = OCLocalizedString(@"Certificate", @"");

		switch (validationResult)
		{
			case OCCertificateValidationResultError:
				_localizedDescription = [NSString stringWithFormat:OCLocalizedString(@"An error occured trying to validate the certificate for %@.", @""), certificate.hostName];
			break;

			case OCCertificateValidationResultReject:
				_localizedDescription = [NSString stringWithFormat:OCLocalizedString(@"The certificate for %@ has previously been rejected by the user.", @""), certificate.hostName];
			break;

			case OCCertificateValidationResultPromptUser:
			case OCCertificateValidationResultUserAccepted:
				_localizedDescription = [NSString stringWithFormat:OCLocalizedString(@"Issues were found while validating the certificate for %@.", @""), certificate.hostName];
			break;

			case OCCertificateValidationResultPassed:
				_localizedDescription = [NSString stringWithFormat:OCLocalizedString(@"Certificate for %@ passed validation.", @""), certificate.hostName];
			break;

			case OCCertificateValidationResultNone:
			break;
		}
	}

	return(self);
}

- (instancetype)initWithRedirectionFromURL:(NSURL *)originalURL toSuggestedURL:(NSURL *)suggestedURL issueHandler:(OCIssueHandler)issueHandler
{
	if ((self = [super init]) != nil)
	{
		_type = OCIssueTypeURLRedirection;
		_level = OCIssueLevelWarning;

		_originalURL = originalURL;
		_suggestedURL = suggestedURL;

		_issueHandler = [issueHandler copy];

		_localizedTitle = OCLocalizedString(@"Redirection", @"");
		_localizedDescription = [NSString stringWithFormat:OCLocalizedString(@"The connection is redirected from %@ to %@.", @""), originalURL.hostAndPort, suggestedURL.hostAndPort];
	}

	return(self);
}

- (instancetype)initWithError:(NSError *)error level:(OCIssueLevel)level issueHandler:(OCIssueHandler)issueHandler
{
	if ((self = [super init]) != nil)
	{
		_type = OCIssueTypeError;
		_level = level;

		_error = error;

		_issueHandler = [issueHandler copy];

		_localizedTitle = OCLocalizedString(@"Error", @"");
		_localizedDescription = _error.localizedDescription;

		if (_localizedDescription==nil) {
			_localizedDescription = _error.description;
		}
	}

	return(self);
}

- (instancetype)initMultipleChoicesWithLocalizedTitle:(NSString *)localizedTitle localizedDescription:(NSString *)localizedDescription choices:(NSArray <OCIssueChoice *> *)choices completionHandler:(OCIssueHandler)issueHandler
{
	if ((self = [super init]) != nil)
	{
		_type = OCIssueTypeMultipleChoice;

		_localizedTitle = localizedTitle;
		_localizedDescription = localizedDescription;

		_choices = choices;
		_issueHandler = [issueHandler copy];
	}

	return(self);
}

- (instancetype)initWithLocalizedTitle:(NSString *)localizedTitle localizedDescription:(NSString *)localizedDescription level:(OCIssueLevel)level issueHandler:(nullable OCIssueHandler)issueHandler
{
	if ((self = [super init]) != nil)
	{
		_type = OCIssueTypeGeneric;

		_localizedTitle = localizedTitle;
		_localizedDescription = localizedDescription;

		_level = level;

		_issueHandler = [issueHandler copy];
	}

	return(self);
}

- (instancetype)initWithIssues:(NSArray <OCIssue *> *)issues completionHandler:(OCIssueHandler)completionHandler
{
	if ((self = [super init]) != nil)
	{
		OCIssueLevel highestLevel = OCIssueLevelInformal;

		_type = OCIssueTypeGroup;

		_issues = issues;
		_issueHandler = [completionHandler copy];

		for (OCIssue *issue in issues)
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
	return (_level != OCIssueLevelError);
}

#pragma mark - Adding issues
- (void)addIssue:(OCIssue *)addIssue
{
	if (_type == OCIssueTypeGroup)
	{
		if (addIssue.type == OCIssueTypeGroup)
		{
			// Add all issues in group
			for (OCIssue *issue in addIssue.issues)
			{
				[self addIssue:issue];
			}
		}
		else
		{
			// Add issues
			if (![_issues isKindOfClass:[NSMutableArray class]])
			{
				_issues = [NSMutableArray arrayWithArray:_issues];
			}

			addIssue.parentIssue = self;
			[(NSMutableArray *)_issues addObject:addIssue];

			if (addIssue.level > _level)
			{
				_level = addIssue.level;
			}
		}
	}
}

#pragma mark - Multiple choice
- (void)selectChoice:(OCIssueChoice *)choice
{
	BOOL madeDecision = NO;

	@synchronized(self)
	{
		if (!_decisionMade)
		{
			[self willChangeValueForKey:@"selectedChoice"];

			_decisionMade = YES;
			_selectedChoice = choice;
			madeDecision = YES;

			[self didChangeValueForKey:@"selectedChoice"];
		}
	}

	if (madeDecision)
	{
		if (choice.choiceHandler != nil)
		{
			choice.choiceHandler(self, choice);
		}

		if (_issueHandler != nil)
		{
			_issueHandler(self, OCIssueDecisionNone);
		}

		if (_parentIssue != nil)
		{
			[_parentIssue _childIssueMadeDecision:self];
		}
	}
}

- (void)cancel
{
	if (_selectedChoice == nil)
	{
		for (OCIssueChoice *choice in _choices)
		{
			if (choice.type == OCIssueChoiceTypeCancel)
			{
				[self selectChoice:choice];
				return;
			}
		}
	}
}

#pragma mark - Decision management
- (void)_childIssueMadeDecision:(OCIssue *)childIssue
{
	if (!_ignoreChildEvents)
	{
		NSUInteger decisionCounts[3] = { 0, 0, 0 };

		for (OCIssue *issue in _issues)
		{
			if (issue.decision < 3)
			{
				decisionCounts[issue.decision]++;
			}
		}

		if (decisionCounts[OCIssueDecisionNone] == 0)
		{
			OCIssueDecision summaryDecision = OCIssueDecisionNone;

			if (decisionCounts[OCIssueDecisionApprove] == _issues.count)
			{
				summaryDecision = OCIssueDecisionApprove;
			}
			else if (decisionCounts[OCIssueDecisionReject] == _issues.count)
			{
				summaryDecision = OCIssueDecisionReject;
			}

			[self _madeDecision:summaryDecision];
		}
	}
}

- (void)_madeDecision:(OCIssueDecision)decision
{
	BOOL madeDecision = NO;

	@synchronized(self)
	{
		if (!_decisionMade)
		{
			[self willChangeValueForKey:@"decision"];

			_decisionMade = YES;
			_decision = decision;
			madeDecision = YES;

			[self didChangeValueForKey:@"decision"];
		}
	}

	if (madeDecision)
	{
		if (_type == OCIssueTypeGroup)
		{
			_ignoreChildEvents = YES;

			for (OCIssue *issue in _issues)
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
	[self _madeDecision:OCIssueDecisionApprove];
}

- (void)reject
{
	[self _madeDecision:OCIssueDecisionReject];
}

- (NSString *)description
{
	NSMutableString *descriptionString = [NSMutableString stringWithFormat:@"<%@: 0x%p, type: ", NSStringFromClass([self class]), self];

	switch (_type)
	{
		case OCIssueTypeGroup:
			[descriptionString appendFormat:@"Group [%@]", _issues];
		break;

		case OCIssueTypeMultipleChoice:
			[descriptionString appendFormat:@"Multiple Choice [%@: %@] : [%@]", _localizedTitle, _localizedDescription, _choices];
		break;

		case OCIssueTypeURLRedirection:
			[descriptionString appendFormat:@"Redirection [%@ -> %@]", _originalURL, _suggestedURL];
		break;

		case OCIssueTypeCertificate:
			[descriptionString appendFormat:@"Certificate [%@ | %@]", _certificate.hostName, _certificate.sha256Fingerprint.asFingerPrintString];
		break;

		case OCIssueTypeGeneric:
			[descriptionString appendFormat:@"Generic [%@: %@]", _localizedTitle, _localizedDescription];
		break;

		case OCIssueTypeError:
			[descriptionString appendFormat:@"Error [%@]", _error];
		break;
	}

	switch (_level)
	{
		case OCIssueLevelInformal:
			[descriptionString appendString:@" (Informal)"];
		break;

		case OCIssueLevelWarning:
			[descriptionString appendString:@" (Warning)"];
		break;

		case OCIssueLevelError:
			[descriptionString appendString:@" (Error)"];
		break;
	}

	[descriptionString appendString:@">"];

	return (descriptionString);
}

#pragma mark - Handling
- (void)appendIssueHandler:(OCIssueHandler)issueHandler
{
	if (_issueHandler == nil)
	{
		_issueHandler = [issueHandler copy];
	}
	else
	{
		OCIssueHandler existingHandler = [_issueHandler copy];
		OCIssueHandler additionalHandler = [issueHandler copy];

		_issueHandler = [^(OCIssue *issue, OCIssueDecision decision) {
			existingHandler(issue, decision);
			additionalHandler(issue, decision);
		} copy];
	}
}

#pragma mark - Signature
- (OCIssueSignature)signature
{
	NSMutableString *signatureString = [NSMutableString stringWithFormat:@"%lu:%lu:%@:%@:", (unsigned long)_level, (unsigned long)_type, _localizedTitle, _localizedDescription];

	switch (_type)
	{
		case OCIssueTypeGroup:
			for (OCIssue *issue in _issues)
			{
				[signatureString appendFormat:@"%@:", issue.signature];
			}
		break;

		case OCIssueTypeMultipleChoice:
			for (OCIssueChoice *choice in _choices)
			{
				[signatureString appendFormat:@"%@[%@]:", choice.label, choice.identifier];
			}
		break;

		case OCIssueTypeURLRedirection:
			[signatureString appendFormat:@"%@ -> %@", _originalURL, _suggestedURL];
		break;

		case OCIssueTypeCertificate:
			[signatureString appendFormat:@"%@:%@", _certificate.hostName, [_certificate.sha256Fingerprint asHexStringWithSeparator:@""]];
		break;

		case OCIssueTypeGeneric:
		break;

		case OCIssueTypeError:
			[signatureString appendFormat:@"%@:%ld", _error.domain, (long)_error.code];
		break;
	}

	return (signatureString);
}

#pragma mark - Filtering
- (NSArray <OCIssue *> *)issuesWithLevelGreaterThanOrEqualTo:(OCIssueLevel)level
{
	return ([self.issues filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"level >= %@", @(level)]]);
}

@end
