//
//  OCConnection+Setup.m
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

#import "OCConnection.h"
#import "NSError+OCError.h"
#import "OCMacros.h"

@implementation OCConnection (Setup)

#pragma mark - Prepare for setup
- (void)prepareForSetupWithOptions:(NSDictionary<NSString *, id> *)options completionHandler:(void(^)(OCIssue *issue, NSURL *suggestedURL, NSArray <OCAuthenticationMethodIdentifier> *supportedMethods, NSArray <OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods))completionHandler
{
	/*
		Setup preparation steps overview:

		1) Query [url]/status.php.
		   - Redirect? Create issue, follow redirect, restart at 1).
		   - Error (no OC status.php content):
		     - check if [url] last path component is "owncloud".
		       - if NO: append owncloud to [url] and restart at 1) with the new URL (so [url]/owncloud/status.php is queried).
		       - if YES: load [url] directly and check if there's a redirection:
		         - if YES: create a redirect issue, use redirection URL as [url] and repeat step 1
		         - if NO: create error issue
		   - Success (OC status.php content): proceed to step 2

		2) Send PROPFIND to [finalurl]/remote.php/dav/files to determine available authentication mechanisms (=> use -requestSupportedAuthenticationMethodsWithOptions:.. for this)
	*/

	// Since this is far easier to implement when making requests synchronously, move the whole method to a private method and execute it asynchronously on a global queue
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
		[self _prepareForSetupWithOptions:options completionHandler:completionHandler];
	});
}

- (void)_prepareForSetupWithOptions:(NSDictionary<NSString *, id> *)options completionHandler:(void(^)(OCIssue *issue, NSURL *suggestedURL, NSArray <OCAuthenticationMethodIdentifier> *supportedMethods, NSArray <OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods))completionHandler
{
	NSString *statusEndpointPath = [self classSettingForOCClassSettingsKey:OCConnectionEndpointIDStatus];
	NSMutableArray <OCIssue *> *issues = [NSMutableArray new];
	NSMutableSet <OCCertificate *> *certificatesUsedInIssues = [NSMutableSet new];
	__block NSUInteger requestCount=0, maxRequestCount = 30;

	// Tools
	void (^AddIssue)(OCIssue *issue) = ^(OCIssue *issue) {
		@synchronized(self)
		{
			if (issue.certificate != nil)
			{
				if ([certificatesUsedInIssues containsObject:issue.certificate])
				{
					return;
				}
				
				[certificatesUsedInIssues addObject:issue.certificate];
			}
		
			[issues addObject:issue];
		}
	};

	void (^AddRedirectionIssue)(NSURL *fromURL, NSURL *toURL) = ^(NSURL *fromURL, NSURL *toURL){
		OCIssue *issue;
		
		issue = [OCIssue issueForRedirectionFromURL:fromURL toSuggestedURL:toURL issueHandler:^(OCIssue *issue, OCIssueDecision decision) {
			if (decision == OCIssueDecisionApprove)
			{
				if (self->_bookmark.originURL == nil)
				{
					self->_bookmark.originURL = self->_bookmark.url;
				}

				self->_bookmark.url = toURL;
			}
		}];

		if ([[self class] isAlternativeBaseURL:toURL safeUpgradeForPreviousBaseURL:fromURL])
		{
			issue.level = OCIssueLevelInformal;
		}

		AddIssue(issue);
	};

	NSError *(^MakeRequest)(NSURL *url, OCHTTPRequest **outRequest) = ^(NSURL *url, OCHTTPRequest **outRequest){
		OCHTTPRequest *request;
		NSError *error = nil;
		
		request = [OCHTTPRequest requestWithURL:url];
		request.forceCertificateDecisionDelegation = YES;
		request.ephermalRequestCertificateProceedHandler = ^(OCHTTPRequest *request, OCCertificate *certificate, OCCertificateValidationResult validationResult, NSError *certificateValidationError, OCConnectionCertificateProceedHandler proceedHandler) {
			switch (validationResult)
			{
				case OCCertificateValidationResultError:
					// Validation failed. Use error where available.
					if (certificateValidationError != nil)
					{
						AddIssue([OCIssue issueForError:certificateValidationError level:OCIssueLevelError issueHandler:nil]);
					}
					else
					{
						AddIssue([OCIssue issueForCertificate:certificate validationResult:validationResult url:request.url level:OCIssueLevelError issueHandler:nil]);
					}

					proceedHandler(NO, nil);
				break;

				case OCCertificateValidationResultNone:
				case OCCertificateValidationResultReject:
					// User rejected this certificate previously, so do not proceed
					AddIssue([OCIssue issueForCertificate:certificate validationResult:validationResult url:request.url level:OCIssueLevelError issueHandler:nil]);

					proceedHandler(NO, nil);
				break;

				case OCCertificateValidationResultPromptUser: {
					// Record issue to prompt user and proceed
					AddIssue([OCIssue issueForCertificate:certificate validationResult:validationResult url:request.url level:OCIssueLevelWarning issueHandler:^(OCIssue *issue, OCIssueDecision decision) {
						if (decision == OCIssueDecisionApprove)
						{
							[certificate userAccepted:YES withReason:OCCertificateAcceptanceReasonUserAccepted description:nil];

							self->_bookmark.certificate = certificate;
							self->_bookmark.certificateModificationDate = [NSDate date];
						}
					}]);
				}

				case OCCertificateValidationResultUserAccepted:
				case OCCertificateValidationResultPassed:
					// Record certificate to show it and to save it to the bookmark
					AddIssue([OCIssue issueForCertificate:certificate validationResult:validationResult url:request.url level:OCIssueLevelInformal issueHandler:^(OCIssue *issue, OCIssueDecision decision) {
						if (decision == OCIssueDecisionApprove)
						{
							self->_bookmark.certificate = certificate;
							self->_bookmark.certificateModificationDate = [NSDate date];
						}
					}]);

					// This is fine!
					proceedHandler(YES, nil);
				break;
			}
		};
		
		error = [self sendSynchronousRequest:request];
		
		if (outRequest != NULL)
		{
			*outRequest = request;
		}
		
		requestCount++;

		// OCLogDebug(@"Loaded URL %@ with error=%@", url, error);

		return (error);
	};

	NSError *(^MakeJSONRequest)(NSURL *url, OCHTTPRequest **outRequest, NSURL **outRedirectionURL, NSDictionary **outJSONDict) = ^(NSURL *url, OCHTTPRequest **outRequest, NSURL **outRedirectionURL, NSDictionary **outJSONDict){
		OCHTTPRequest *request = nil;
		NSError *error;
		
		if ((error = MakeRequest(url, &request)) == nil)
		{
			if (request.httpResponse.status.isSuccess)
			{
				NSDictionary *jsonDict;

				if ((jsonDict = [request.httpResponse bodyConvertedDictionaryFromJSONWithError:&error]) != nil)
				{
					if (outJSONDict != NULL)
					{
						*outJSONDict = jsonDict;
					}
				}
			}
			else if (request.httpResponse.status.isRedirection)
			{
				NSURL *redirectionURL;
				
				if ((redirectionURL = request.httpResponse.redirectURL) != nil)
				{
					if (outRedirectionURL != NULL)
					{
						*outRedirectionURL = redirectionURL;
					}
				}
			}
		}
		
		if (outRequest != NULL)
		{
			*outRequest = request;
		}
		
		return (error);
	};

	NSError *(^MakeStatusRequest)(NSURL *url, OCHTTPRequest **outRequest, NSURL **outSuggestedURL) = ^(NSURL *url, OCHTTPRequest **outRequest, NSURL **outSuggestedURL){
		NSDictionary *jsonDict = nil;
		NSError *error = nil;
		NSURL *redirectionURL = nil;
		OCHTTPRequest *request = nil;
		NSURL *statusURL = [url URLByAppendingPathComponent:statusEndpointPath];

		if ((error = MakeJSONRequest(statusURL, &request, &redirectionURL, &jsonDict)) == nil)
		{
			if (((jsonDict!=nil) && (jsonDict[@"version"] == nil)) || (jsonDict==nil))
			{
				error = OCError(OCErrorServerDetectionFailed);
			}
			else
			{
				NSString *serverVersion = nil;
				NSNumber *maintenanceMode = nil;
				NSString *product = nil;

				if ((jsonDict!=nil) && ((serverVersion = jsonDict[@"version"]) != nil))
				{
					product = jsonDict[@"productname"];

					error = [self supportsServerVersion:serverVersion product:product longVersion:[OCConnection serverLongProductVersionStringFromServerStatus:jsonDict]];
				}

				if ((jsonDict!=nil) && ((maintenanceMode = jsonDict[@"maintenance"]) != nil))
				{
					if (maintenanceMode.boolValue)
					{
						error = OCError(OCErrorServerInMaintenanceMode);
					}
				}

				if ((error == nil) && (redirectionURL != nil))
				{
					NSURL *suggestedURL = nil;
					
					if ((suggestedURL = [[self class] extractBaseURLFromRedirectionTargetURL:redirectionURL originalURL:statusURL originalBaseURL:url]) != nil)
					{
						if (outSuggestedURL != NULL)
						{
							*outSuggestedURL = suggestedURL;
						}
					}
				}
			}
		}
		else
		{
			// Treat non-network-related errors as JSON decoding failure and therefore as server detection failure
			if ([error.domain isEqualToString:NSCocoaErrorDomain])
			{
				error = OCError(OCErrorServerDetectionFailed);
			}
		}
		
		if (outRequest != NULL)
		{
			*outRequest = request;
		}

		return (error);
	};

	// Variables
	NSURL *url = self.bookmark.url;
	NSURL *successURL = nil;

	NSError *error = nil;
	
	BOOL completed = NO;
	NSURL *urlForCreationOfRedirectionIssueIfSuccessful = nil;
	NSURL *urlForTryingRootURL = nil;
	NSURL *lastURLTried = nil;

	// Plain-text HTTP check
	if ([url.scheme.lowercaseString isEqualToString:@"http"])
	{
		OCIssue *issue = nil;

		switch (OCConnection.setupHTTPPolicy)
		{
			case OCConnectionSetupHTTPPolicyAllow:
				// Pass
			break;

			case OCConnectionSetupHTTPPolicyAuto:
			case OCConnectionSetupHTTPPolicyWarn:
				// Warn user about HTTP usage
				if (self.bookmark.userInfo[OCBookmarkUserInfoKeyAllowHTTPConnection] == nil)
				{
					issue = [OCIssue issueWithLocalizedTitle:OCLocalized(@"Insecure HTTP URL") localizedDescription:OCLocalized(@"The URL you provided uses the HTTP rather than the HTTPS scheme. If you continue, your communication will not be encrypted.") level:OCIssueLevelWarning issueHandler:^(OCIssue * _Nonnull issue, OCIssueDecision decision) {
						switch (decision)
						{
							case OCIssueDecisionApprove:
								self.bookmark.userInfo[OCBookmarkUserInfoKeyAllowHTTPConnection] = [NSDate new];
							break;

							default:
								self.bookmark.userInfo[OCBookmarkUserInfoKeyAllowHTTPConnection] = nil;
							break;
						}
					}];
				}
			break;

			case OCConnectionSetupHTTPPolicyForbidden:
				// HTTP forbidden
				self.bookmark.userInfo[OCBookmarkUserInfoKeyAllowHTTPConnection] = nil;

				issue = [OCIssue issueWithLocalizedTitle:OCLocalized(@"Insecure HTTP URL forbidden") localizedDescription:OCLocalized(@"The URL you provided uses the HTTP rather than the HTTPS scheme, so your communication would not be encrypted.") level:OCIssueLevelError issueHandler:^(OCIssue * _Nonnull issue, OCIssueDecision decision) {
					self.bookmark.userInfo[OCBookmarkUserInfoKeyAllowHTTPConnection] = nil;
				}];
			break;
		}

		if (issue != nil)
		{
			completionHandler(issue, nil, nil, nil);
			return;
		}
	}

	// Query [url]/status.php
	while (!completed)
	{
		NSURL *newBookmarkURL = nil;
		OCHTTPRequest *statusRequest = nil;

		if ((lastURLTried!=nil) && ([lastURLTried isEqual:url]))
		{
			// No new URLs to try. Detection failed.
			AddIssue([OCIssue issueForError:OCError(OCErrorServerDetectionFailed) level:OCIssueLevelError issueHandler:nil]);
			break;
		}

		lastURLTried = url;

		if ((error = MakeStatusRequest(url, &statusRequest, &newBookmarkURL)) != nil)
		{
			if ([error isOCErrorWithCode:OCErrorServerDetectionFailed])
			{
				if (statusRequest.httpResponse.status.code != 0)
				{
					// HTTP request was answered
					if (![[url lastPathComponent] isEqual:@"owncloud"])
					{
						if (urlForCreationOfRedirectionIssueIfSuccessful != nil)
						{
							AddRedirectionIssue(urlForCreationOfRedirectionIssueIfSuccessful, url);
						}
					
						urlForCreationOfRedirectionIssueIfSuccessful = url;
						urlForTryingRootURL = url;

						url = [url URLByAppendingPathComponent:@"owncloud"];
						continue;
					}
					else
					{
						// Check server root directory for a redirect
						if (urlForTryingRootURL != nil)
						{
							OCHTTPRequest *rootURLRequest = nil;
							NSURL *rootURL = urlForTryingRootURL;

							if ((error = MakeRequest(rootURL, &rootURLRequest)) != nil)
							{
								// Network Error
								AddIssue([OCIssue issueForError:error level:OCIssueLevelError issueHandler:nil]);
								completed = YES;
							}
							else
							{
								// Check response for redirect
								if (rootURLRequest.httpResponse.status.isRedirection)
								{
									if (rootURLRequest.httpResponse.redirectURL != nil)
									{
										urlForCreationOfRedirectionIssueIfSuccessful = urlForTryingRootURL;
										url = rootURLRequest.httpResponse.redirectURL;
										urlForTryingRootURL = nil;

										continue;
									}
								}
							}

							urlForTryingRootURL = nil;
						}
						else
						{
							// This is just not an ownCloud server
							AddIssue([OCIssue issueForError:OCError(OCErrorServerDetectionFailed) level:OCIssueLevelError issueHandler:nil]);
							completed = YES;
						}
					}
				}
				else
				{
					// Detection failed
					completed = YES;
				}
			}
			else
			{
				// Network Error
				AddIssue([OCIssue issueForError:error level:OCIssueLevelError issueHandler:nil]);
				completed = YES;
			}
		}
		else
		{
			if (newBookmarkURL != nil)
			{
				// Redirection
				AddRedirectionIssue(url, newBookmarkURL);
				url = newBookmarkURL;
			}
			else
			{
				// Successfully detected OC instance!
				if (urlForCreationOfRedirectionIssueIfSuccessful != nil)
				{
					if (![_bookmark.url isEqual:url])
					{
						AddRedirectionIssue(urlForCreationOfRedirectionIssueIfSuccessful, url);
					}

					urlForCreationOfRedirectionIssueIfSuccessful = nil;
				}
				
				successURL = url;
			
				completed = YES;
			}
		}
		
		if (requestCount > maxRequestCount)
		{
			// Too many redirects
			AddIssue([OCIssue issueForError:OCError(OCErrorServerTooManyRedirects) level:OCIssueLevelError issueHandler:nil]);
			completed = YES;
		}
		
		urlForCreationOfRedirectionIssueIfSuccessful = nil;
	};
	
	if (completionHandler != nil)
	{
		__block NSArray<OCAuthenticationMethodIdentifier> *supportedMethodIdentifiers = nil;

		if (successURL != nil)
		{
			dispatch_group_t waitForSupportedAuthenticationMethodsGroup = NULL;
		
			if ((waitForSupportedAuthenticationMethodsGroup = dispatch_group_create()) != NULL)
			{
				__block NSError *supportedAuthError = nil;
				
				NSURL *savedBookmarkURL = _bookmark.url; // Save original bookmark URL
				
				do
				{
					dispatch_group_enter(waitForSupportedAuthenticationMethodsGroup);
				
					_bookmark.url = successURL;
				
					[self requestSupportedAuthenticationMethodsWithOptions:nil completionHandler:^(NSError *error, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods) {
						supportedAuthError = error;
						supportedMethodIdentifiers = supportedMethods;

						dispatch_group_leave(waitForSupportedAuthenticationMethodsGroup);
					}];
					
					dispatch_group_wait(waitForSupportedAuthenticationMethodsGroup, DISPATCH_TIME_FOREVER);
					
					if (supportedAuthError!=nil)
					{
						if ([supportedAuthError isOCErrorWithCode:OCErrorAuthorizationRedirect])
						{
							NSURL *newBookmarkURL = supportedAuthError.ocErrorInfoDictionary[OCAuthorizationMethodAlternativeServerURLKey];
							
							AddRedirectionIssue(successURL, newBookmarkURL);

							successURL = newBookmarkURL;
						}
						else
						{
							AddIssue([OCIssue issueForError:supportedAuthError level:OCIssueLevelError issueHandler:nil]);
						}
					}

					if (supportedMethodIdentifiers.count == 0)
					{
						AddIssue([OCIssue issueForError:[NSError errorWithDomain:OCErrorDomain code:OCErrorServerNoSupportedAuthMethods userInfo:@{
							NSLocalizedDescriptionKey : OCLocalizedString(@"Server doesn't seem to support any authentication method supported by this app.", @"") }] level:OCIssueLevelError issueHandler:nil]);
					}

					if (requestCount > maxRequestCount)
					{
						// Too many redirects
						AddIssue([OCIssue issueForError:OCError(OCErrorServerTooManyRedirects) level:OCIssueLevelError issueHandler:nil]);
						successURL = nil;
					}
					
					requestCount++;
				}while ((supportedAuthError != nil) && [supportedAuthError isOCErrorWithCode:OCErrorAuthorizationRedirect] && (successURL!=nil));

				_bookmark.url = savedBookmarkURL; // Restore bookmark URL
			}
		}

		completionHandler([OCIssue issueForIssues:issues completionHandler:nil], successURL, supportedMethodIdentifiers, [self filteredAndSortedMethodIdentifiers:supportedMethodIdentifiers]);
	}
}

@end
