//
//  OCHTTPPolicyBookmark.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.07.20.
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

#import "OCHTTPPolicyBookmark.h"
#import "OCBookmarkManager.h"
#import "OCConnection.h"
#import "OCCertificateRuleChecker.h"
#import "OCLogger.h"
#import "NSError+OCError.h"
#import "OCMacros.h"

@interface OCHTTPPolicyBookmark ()
{
	__weak OCBookmark *_bookmark;
	__weak OCConnection *_connection;
}
@end

@implementation OCHTTPPolicyBookmark

- (instancetype)initWithBookmarkUUID:(OCBookmarkUUID)bookmarkUUID
{
	if ((self = [super initWithIdentifier:OCHTTPPolicyIdentifierConnection]) != nil)
	{
		_bookmarkUUID = bookmarkUUID;
	}

	return (self);
}

- (instancetype)initWithBookmark:(OCBookmark *)bookmark;
{
	if ((self = [super initWithIdentifier:OCHTTPPolicyIdentifierConnection]) != nil)
	{
		_bookmark = bookmark;
		_bookmarkUUID = bookmark.uuid;
	}

	return (self);
}

- (instancetype)initWithConnection:(OCConnection *)connection
{
	if ((self = [super initWithIdentifier:OCHTTPPolicyIdentifierConnection]) != nil)
	{
		_connection = connection;
		_bookmarkUUID = connection.bookmark.uuid;
	}

	return (self);
}

- (void)validateCertificate:(nonnull OCCertificate *)certificate forRequest:(nonnull OCHTTPRequest *)request validationResult:(OCCertificateValidationResult)validationResult validationError:(nonnull NSError *)validationError proceedHandler:(nonnull OCConnectionCertificateProceedHandler)proceedHandler
{
	@synchronized (self)
	{
		if (_connection != nil)
		{
			_bookmark = _connection.bookmark;
		}

		if (_bookmark == nil)
		{
			_bookmark = [OCBookmarkManager.sharedBookmarkManager bookmarkForUUID:_bookmarkUUID];
		}
	}

	if (_bookmark != nil)
	{
		[OCHTTPPolicyBookmark validateBookmark:_bookmark certificate:certificate forRequest:request validationResult:validationResult validationError:validationError proceedHandler:proceedHandler];
	}
	else
	{
		OCLogWarning(@"No bookmark found for %@ - not performing certificate check, falling back to super implementation", _bookmarkUUID);
		[super validateCertificate:certificate forRequest:request validationResult:validationResult validationError:validationError proceedHandler:proceedHandler];
	}
}

+ (void)validateBookmark:(OCBookmark *)bookmark certificate:(nonnull OCCertificate *)certificate forRequest:(nonnull OCHTTPRequest *)request validationResult:(OCCertificateValidationResult)validationResult validationError:(nonnull NSError *)validationError proceedHandler:(nonnull OCConnectionCertificateProceedHandler)proceedHandler
{
	BOOL defaultWouldProceed = ((validationResult == OCCertificateValidationResultPassed) || (validationResult == OCCertificateValidationResultUserAccepted));
	BOOL fulfillsBookmarkRequirements = defaultWouldProceed;

	// Enforce bookmark certificate
	if (bookmark.certificate != nil)
	{
		BOOL extendedValidationPassed = NO;
		NSString *extendedValidationRule = nil;

		if ((extendedValidationRule = [OCConnection classSettingForOCClassSettingsKey:OCConnectionCertificateExtendedValidationRule]) != nil)
		{
			// Check extended validation rule
			OCCertificateRuleChecker *ruleChecker = nil;

			if ((ruleChecker = [OCCertificateRuleChecker ruleWithCertificate:bookmark.certificate newCertificate:certificate rule:extendedValidationRule]) != nil)
			{
				extendedValidationPassed = [ruleChecker evaluateRule];
			}
		}
		else
		{
			// Check if certificate SHA-256 fingerprints are identical
			extendedValidationPassed = [bookmark.certificate isEqual:certificate];
		}

		if (extendedValidationPassed)
		{
			fulfillsBookmarkRequirements = YES;
		}
		else
		{
			// Evaluate the renewal acceptance rule to determine if this certificate should be used instead
			NSString *renewalAcceptanceRule = nil;

			fulfillsBookmarkRequirements = NO;

			OCLogWarning(@"Certificate %@ does not match bookmark certificate %@. Checking with rule: %@", OCLogPrivate(certificate), OCLogPrivate(bookmark.certificate), OCLogPrivate(renewalAcceptanceRule));

			if ((renewalAcceptanceRule = [OCConnection classSettingForOCClassSettingsKey:OCConnectionRenewedCertificateAcceptanceRule]) != nil)
			{
				OCCertificateRuleChecker *ruleChecker;

				if ((ruleChecker = [OCCertificateRuleChecker ruleWithCertificate:bookmark.certificate newCertificate:certificate rule:renewalAcceptanceRule]) != nil)
				{
					fulfillsBookmarkRequirements = [ruleChecker evaluateRule];

					if (fulfillsBookmarkRequirements)	// New certificate fulfills the requirements of the renewed certificate acceptance rule
					{
						// Auto-accept successor to user-accepted certificate that also would prompt for confirmation
						if ((bookmark.certificate.userAccepted) && (validationResult == OCCertificateValidationResultPromptUser))
						{
							[certificate userAccepted:YES withReason:OCCertificateAcceptanceReasonAutoAccepted description:[NSString stringWithFormat:@"Certificate fulfills renewal acceptance rule: %@", ruleChecker.rule]];

							validationResult = OCCertificateValidationResultUserAccepted;
						}

						// Update bookmark certificate
						bookmark.certificate = certificate;
						bookmark.certificateModificationDate = [NSDate date];

						[[NSNotificationCenter defaultCenter] postNotificationName:OCBookmarkUpdatedNotification object:bookmark];
						[bookmark postCertificateUserApprovalUpdateNotification];

						OCLogWarning(@"Updated stored certificate for bookmark %@ with certificate %@", OCLogPrivate(bookmark), certificate);
					}

					defaultWouldProceed = fulfillsBookmarkRequirements;
				}
			}

			OCLogWarning(@"Certificate %@ renewal rule check result: %d", OCLogPrivate(certificate), fulfillsBookmarkRequirements);
		}
	}

	if (proceedHandler != nil)
	{
		NSError *errorIssue = nil;
		BOOL doProceed = NO, changeUserAccepted = NO;

		if (defaultWouldProceed && request.forceCertificateDecisionDelegation)
		{
			// enforce bookmark certificate where available
			doProceed = fulfillsBookmarkRequirements;
		}
		else
		{
			// Default to safe option: reject
			changeUserAccepted = (validationResult == OCCertificateValidationResultPromptUser);
			doProceed = NO;
		}

		if (!doProceed)
		{
			errorIssue = OCError(OCErrorRequestServerCertificateRejected);

			OCErrorAddDateFromResponse(errorIssue, request.httpResponse);

			// Embed issue
			OCIssue *issue = [OCIssue issueForCertificate:certificate validationResult:validationResult url:request.url level:OCIssueLevelWarning issueHandler:^(OCIssue *issue, OCIssueDecision decision) {
				if (decision == OCIssueDecisionApprove)
				{
					if (changeUserAccepted)
					{
						[certificate userAccepted:YES withReason:OCCertificateAcceptanceReasonUserAccepted description:nil];
					}

					bookmark.certificate = certificate;
					bookmark.certificateModificationDate = [NSDate date];

					[[NSNotificationCenter defaultCenter] postNotificationName:OCBookmarkUpdatedNotification object:bookmark];
					[bookmark postCertificateUserApprovalUpdateNotification];
				}
			}];

			if (validationResult == OCCertificateValidationResultPassed)
			{
				issue.localizedTitle = OCLocalized(@"Certificate changed");

				if (validationResult == OCCertificateValidationResultPassed)
				{
					issue.localizedDescription = [NSString stringWithFormat:OCLocalizedString(@"The certificate for %@ passes TLS validation but doesn't pass the acceptance rule to replace the certificate for %@.", nil), certificate.hostName, bookmark.certificate.hostName];
				}
			}

			errorIssue = [errorIssue errorByEmbeddingIssue:issue];
		}

		proceedHandler(doProceed, errorIssue);
	}
}

#pragma mark - Secure coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if ((self = [super initWithCoder:coder]) != nil)
	{
		_bookmarkUUID = [coder decodeObjectOfClass:NSUUID.class forKey:@"bookmarkUUID"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];

	[coder encodeObject:_bookmarkUUID forKey:@"bookmarkUUID"];
}

@end
