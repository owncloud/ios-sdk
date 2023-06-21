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
#import "NSURL+OCURLNormalization.h"
#import "OCServerLocator.h"
#import "OCMacros.h"
#import "OCAuthenticationMethodOpenIDConnect.h"
#import "OCServerInstance.h"
#import "OCHTTPPipelineManager.h"
#import "NSURL+OCURLQueryParameterExtensions.h"

@interface OCAuthenticationMethod (RequestAuthentication)
+ (OCHTTPRequest *)authorizeRequest:(OCHTTPRequest *)request withAuthenticationMethodIdentifier:(OCAuthenticationMethodIdentifier)authenticationMethodIdentifier authenticationData:(NSData *)authenticationData;
@end

@implementation OCConnection (Setup)

#pragma mark - Prepare for setup
- (void)prepareForSetupWithOptions:(NSDictionary<OCConnectionSetupOptionKey, id> *)options completionHandler:(void(^)(OCIssue *issue, NSURL *suggestedURL, NSArray <OCAuthenticationMethodIdentifier> *supportedMethods, NSArray <OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods, OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions generationOptions))completionHandler
{
	/*
		Setup preparation steps overview:

		1) Perform server location if username is provided and flag for it is passed

		2) Query [url]/.well-known/webfinger?resource=https%3A%2F%2Furl
		   - Error -> ignore
		   - Success (Example: `{"subject":"acct:me","links":[{"rel":"http://openid.net/specs/connect/1.0/issuer","href":"https://ocis.ocis-wopi.latest.owncloud.works"}]}` )
		        - links[rel=http://openid.net/specs/connect/1.0/issuer]['href'] in JSON response?
		        	-> use as new base URL, OpenID Connect should be found via [new base URL]/.well-known/openid-configuration by requestSupportedAuthenticationMethodsWithOptions…
		        	-> skip step 3

		3) Query [url]/status.php.
		   - Redirect? Create issue, follow redirect, restart at 1).
		   - Error (no OC status.php content):
		     - check if [url] last path component is "owncloud".
		       - if NO: append owncloud to [url] and restart at 1) with the new URL (so [url]/owncloud/status.php is queried).
		       - if YES: load [url] directly and check if there's a redirection:
		         - if YES: create a redirect issue, use redirection URL as [url] and repeat step 1
		         - if NO: create error issue
		   - Success (OC status.php content): proceed to step 4

		4) Send authentication method provided requests and parse the responses to determine available authentication mechanism via -requestSupportedAuthenticationMethodsWithOptions:..
	*/

	// Since this is far easier to implement when making requests synchronously, move the whole method to a private method and execute it asynchronously on a global queue
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
		[self _prepareForSetupWithOptions:options completionHandler:completionHandler];
	});
}

- (void)_prepareForSetupWithOptions:(NSDictionary<OCConnectionSetupOptionKey, id> *)options completionHandler:(void(^)(OCIssue *issue, NSURL *suggestedURL, NSArray <OCAuthenticationMethodIdentifier> *supportedMethods, NSArray <OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods, OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions generationOptions))completionHandler
{
	NSString *statusEndpointPath = [self classSettingForOCClassSettingsKey:OCConnectionEndpointIDStatus];
	NSMutableArray <OCIssue *> *issues = [NSMutableArray new];
	NSMutableSet <OCCertificate *> *certificatesUsedInIssues = [NSMutableSet new];
	__block NSUInteger requestCount=0, maxRequestCount = 30;
	OCServerLocatorIdentifier serverLocatorIdentifier = OCServerLocator.useServerLocatorIdentifier;
	NSURL *webFingerAccountInfoURL = nil;
	NSURL *webFingerAlternativeIDPBaseURL = nil;
	NSURL *refererForIDPURL = nil;

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

	NSError *(^MakeRawRequest)(OCHTTPRequest *request) = ^(OCHTTPRequest *request) {
		NSError *error = nil;

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

							[self->_bookmark.certificateStore storeCertificate:certificate forHostname:request.hostname];
						}
					}]);
				}

				case OCCertificateValidationResultUserAccepted:
				case OCCertificateValidationResultPassed:
					// Record certificate to show it and to save it to the bookmark
					AddIssue([OCIssue issueForCertificate:certificate validationResult:validationResult url:request.url level:OCIssueLevelInformal issueHandler:^(OCIssue *issue, OCIssueDecision decision) {
						if (decision == OCIssueDecisionApprove)
						{
							[self->_bookmark.certificateStore storeCertificate:certificate forHostname:request.hostname];
						}
					}]);

					// This is fine!
					proceedHandler(YES, nil);
				break;
			}
		};

		error = [self sendSynchronousRequest:request];

		requestCount++;

		// OCLogDebug(@"Loaded URL %@ with error=%@", url, error);

		return (error);
	};

	NSError *(^MakeRequest)(NSURL *url, BOOL handleRedirectLocally, OCHTTPRequest **outRequest) = ^(NSURL *url, BOOL handleRedirectLocally, OCHTTPRequest **outRequest) {
		OCHTTPRequest *request;
		NSError *error = nil;

		request = [OCHTTPRequest requestWithURL:url];
		if (handleRedirectLocally)
		{
			request.redirectPolicy = OCHTTPRequestRedirectPolicyHandleLocally;
		}

		error = MakeRawRequest(request);

		if (outRequest != NULL)
		{
			*outRequest = request;
		}

		return (error);
	};

	NSError *(^MakeJSONRequest)(NSURL *url, BOOL handleRedirectLocally, OCHTTPRequest **outRequest, NSURL **outRedirectionURL, NSDictionary **outJSONDict) = ^(NSURL *url, BOOL handleRedirectLocally, OCHTTPRequest **outRequest, NSURL **outRedirectionURL, NSDictionary **outJSONDict){
		OCHTTPRequest *request = nil;
		NSError *error;
		
		if ((error = MakeRequest(url, handleRedirectLocally, &request)) == nil)
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
			else if (request.httpResponse.status.code == OCHTTPStatusCodeMOVED_PERMANENTLY)
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

		if ((error = MakeJSONRequest(statusURL, NO, &request, &redirectionURL, &jsonDict)) == nil)
		{
			if (((jsonDict!=nil) && (jsonDict[@"version"] == nil)) || (jsonDict==nil))
			{
				error = OCError(OCErrorServerDetectionFailed);
			}
			else
			{
				NSString *serverVersion = nil;
				NSString *product = nil;

				if ((jsonDict!=nil) && ((serverVersion = jsonDict[@"version"]) != nil))
				{
					product = jsonDict[@"productname"];

					error = [self supportsServerVersion:serverVersion product:product longVersion:[OCConnection serverLongProductVersionStringFromServerStatus:jsonDict] allowHiddenVersion:YES];
				}

				if ((jsonDict!=nil) && ([OCConnection validateStatus:jsonDict] == OCConnectionStatusValidationResultMaintenance))
				{
					error = OCError(OCErrorServerInMaintenanceMode);
				}

				if ((error == nil) && (redirectionURL != nil))
				{
					NSURL *suggestedURL = nil;
					
					if ((suggestedURL = [[self class] extractBaseURLFromRedirectionTargetURL:redirectionURL originalURL:statusURL originalBaseURL:url fallbackToRedirectionTargetURL:YES]) != nil)
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
	NSCountedSet<NSString *> *triedRootURLStrings = [NSCountedSet new];

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
			completionHandler(issue, nil, nil, nil, nil);
			return;
		}
	}

	// Locate server by user name
	if (serverLocatorIdentifier != nil)
	{
		// Determine userName
		NSString *userName;

		userName = options[OCConnectionSetupOptionUserName];

		if (userName == nil) { userName = self.bookmark.serverLocationUserName; }
		if (userName == nil) { userName = self.bookmark.userName; }

		if (userName == nil)
		{
			completionHandler([OCIssue issueForError:OCError(OCErrorInsufficientParameters) level:OCIssueLevelError issueHandler:nil], nil, nil, nil, nil);
			return;
		}

		// Determine locator
		OCServerLocator *locator = [OCServerLocator serverLocatorForIdentifier:serverLocatorIdentifier];

		if (locator == nil)
		{
			completionHandler([OCIssue issueForError:OCError(OCErrorUnknown) level:OCIssueLevelError issueHandler:nil], nil, nil, nil, nil);
			return;
		}

		locator.url = url;
		locator.userName = userName;
		locator.requestSender = MakeRawRequest;
		locator.options = options;

		// Perform server location
		NSError *locatorError = [locator locate];

		if (locatorError != nil)
		{
			if (completionHandler != nil)
			{
				completionHandler([OCIssue issueForError:locatorError level:OCIssueLevelError issueHandler:nil], nil, nil, nil, nil);
				return;
			}
		}
		else if (locator.url != nil)
		{
			// Use URL returned from locator
			if (![locator.url isEqual:url])
			{
				if (_bookmark.originURL == nil)
				{
					_bookmark.originURL = _bookmark.url;
				}

				_bookmark.serverLocationUserName = locator.userName;
				_bookmark.url = locator.url;
				url = locator.url;
			}
		}
	}

	// WEBFINGER
	NSURL *webfingerRootURL = nil;
	NSArray <OCAuthenticationMethodIdentifier> *allowedAuthenticationMethodIdentifiers = [self classSettingForOCClassSettingsKey:OCConnectionAllowedAuthenticationMethodIDs];

	// - check that OIDC is allowed - and only perform WebFinger if it is
	if ((allowedAuthenticationMethodIdentifiers == nil) || // default: all allowed
	    ((allowedAuthenticationMethodIdentifiers != nil) && [allowedAuthenticationMethodIdentifiers containsObject:OCAuthenticationMethodIdentifierOpenIDConnect])) // list provided, only continue if OIDC is part of it
	{
		webfingerRootURL = url.rootURL;
	}

	// - query [url]/.well-known/webfinger?resource=https%3A%2F%2Furl - WebFinger https://github.com/owncloud/enterprise/issues/5579
	if (webfingerRootURL != nil)
	{
		NSURL *webFingerLookupURL = [[url URLByAppendingPathComponent:@".well-known/webfinger" isDirectory:NO] urlByAppendingQueryParameters:@{
			@"resource" : webfingerRootURL.absoluteString
		} replaceExisting:YES];

		NSURL *webFingerAccountMeURL = [[url URLByAppendingPathComponent:@".well-known/webfinger" isDirectory:NO] urlByAppendingQueryParameters:@{
			@"resource" : [NSString stringWithFormat:@"acct:me@%@", url.host]
		} replaceExisting:YES];

		if (webFingerLookupURL != nil)
		{
			NSDictionary *jsonDict = nil;
			NSError *error = nil;
			NSURL *redirectionURL = nil;
			OCHTTPRequest *request = nil;

			if ((error = MakeJSONRequest(webFingerLookupURL, YES, &request, &redirectionURL, &jsonDict)) == nil)
			{
				if (jsonDict != nil)
				{
					// Example: {"subject":"acct:me@host","links":[{"rel":"http://openid.net/specs/connect/1.0/issuer","href":"https://ocis.ocis-wopi.latest.owncloud.works"}]}
					// Require subject = rootURL.absoluteString
					if ([jsonDict[@"subject"] isEqual:webfingerRootURL.absoluteString])
					{
						NSArray<NSDictionary<NSString*,id> *> *linksArray;

						// Look for first link with relation http://openid.net/specs/connect/1.0/issuer
						if ((linksArray = OCTypedCast(jsonDict[@"links"], NSArray)) != nil)
						{
							for (id link in linksArray)
							{
								NSDictionary<NSString*,id> *linkDict;

								if ((linkDict = OCTypedCast(link, NSDictionary)) != nil)
								{
									if ([linkDict[@"rel"] isEqual:@"http://openid.net/specs/connect/1.0/issuer"])
									{
										NSString *urlString;

										if ((urlString = OCTypedCast(linkDict[@"href"],NSString)) != nil)
										{
											if ((successURL = [NSURL URLWithString:urlString]) != nil)
											{
												completed = YES; // Skip status.php check step
												webFingerAccountInfoURL = webFingerAccountMeURL;
												webFingerAlternativeIDPBaseURL = successURL; 
												refererForIDPURL = url;
												break;
											}
										}
									}
								}
							}
						}
					}
				}
			}
			else
			{
				OCLogDebug(@"Error performing webfinger lookup: %@", error);
			}
		}
	}

	// Query [url]/status.php
	while (!completed)
	{
		NSURL *newBookmarkURL = nil;
		OCHTTPRequest *statusRequest = nil;
		NSString *absoluteURLString = url.absoluteString;
		NSURL *baseURL = nil;

		if ((absoluteURLString==nil) ||
		   ((absoluteURLString != nil) && ([triedRootURLStrings countForObject:absoluteURLString] >= 1))) // Limit requests per URL to 1
		{
			// No new URL to try. Detection failed.
			AddIssue([OCIssue issueForError:OCError(OCErrorServerDetectionFailed) level:OCIssueLevelError issueHandler:nil]);
			break;
		}

		[triedRootURLStrings addObject:absoluteURLString];

		if ((error = MakeStatusRequest(url, &statusRequest, &newBookmarkURL)) != nil)
		{
			baseURL = url;

			if ([error isOCErrorWithCode:OCErrorServerDetectionFailed])
			{
				if (statusRequest.httpResponse.status.code != 0)
				{
					// HTTP request was answered
					if (statusRequest.httpResponse.status.code == OCHTTPStatusCodeMOVED_PERMANENTLY)
					{
					 	if (urlForCreationOfRedirectionIssueIfSuccessful != nil)
					 	{
					 		// Record previous redirect as issue
							if (![_bookmark.url isEqual:url])
							{
								if (![_bookmark.url hasSameSchemeHostAndPortAs:url])
								{
									// Redirect to different host or scheme
							 		AddRedirectionIssue(urlForCreationOfRedirectionIssueIfSuccessful, url);
								}
								else
								{
									// Redirect on same host, using same scheme
									if (_bookmark.originURL == nil)
									{
										_bookmark.originURL = self->_bookmark.url;
									}

									_bookmark.url = url;
								}
							}
					 	}

						if (statusRequest.httpResponse.redirectURL != nil)
						{
							// Save data needed to record this redirection as issue in case the redirect succeeds
							urlForCreationOfRedirectionIssueIfSuccessful = url;

							url = [OCConnection extractBaseURLFromRedirectionTargetURL:statusRequest.httpResponse.redirectURL originalURL:statusRequest.effectiveURL originalBaseURL:baseURL fallbackToRedirectionTargetURL:YES];

							continue;
						}
					}
					else
					{
						// This is just not an ownCloud server
						AddIssue([OCIssue issueForError:OCError(OCErrorServerDetectionFailed) level:OCIssueLevelError issueHandler:nil]);
						completed = YES;
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
						if (![_bookmark.url hasSameSchemeHostAndPortAs:url])
						{
							// Redirect to different host or scheme
							AddRedirectionIssue(urlForCreationOfRedirectionIssueIfSuccessful, url);
						}
						else
						{
							// Redirect on same host, using same scheme
							if (_bookmark.originURL == nil)
							{
								_bookmark.originURL = self->_bookmark.url;
							}

							_bookmark.url = url;
						}
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

		requestCount++;

		urlForCreationOfRedirectionIssueIfSuccessful = nil;
	};
	
	if (completionHandler != nil)
	{
		NSMutableDictionary<OCAuthenticationMethodKey, id> *detectionOptions = [NSMutableDictionary new];

		if (webFingerAccountInfoURL != nil)
		{
			detectionOptions[OCAuthenticationMethodWebFingerAccountLookupURLKey] = webFingerAccountInfoURL;
			detectionOptions[OCAuthenticationMethodAuthenticationRefererURL] = refererForIDPURL;
			detectionOptions[OCAuthenticationMethodSkipWWWAuthenticateChecksKey] = @(YES);
			// detectionOptions[OCAuthenticationMethodAllowedMethods] = @[ OCAuthenticationMethodIdentifierOpenIDConnect ]; // implemented, but not used/needed at the moment
		}

		if (webFingerAlternativeIDPBaseURL != nil)
		{
			detectionOptions[OCAuthenticationMethodWebFingerAlternativeIDPKey] = webFingerAlternativeIDPBaseURL;
		}

		if (detectionOptions.count == 0)
		{
			detectionOptions = nil;
		}

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
				
					[self requestSupportedAuthenticationMethodsWithOptions:detectionOptions completionHandler:^(NSError *error, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods) {
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

		completionHandler([OCIssue issueForIssues:issues completionHandler:nil], successURL, supportedMethodIdentifiers, [self filteredAndSortedMethodIdentifiers:(supportedMethodIdentifiers == nil) ? @[] : supportedMethodIdentifiers], detectionOptions);
	}
}



#pragma mark - Retrieve instances
- (void)retrieveAvailableInstancesWithOptions:(nullable OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options authenticationMethodIdentifier:(OCAuthenticationMethodIdentifier)authenticationMethodIdentifier authenticationData:(NSData *)authenticationData completionHandler:(void(^)(NSError * _Nullable error, NSArray<OCServerInstance *> * _Nullable availableInstances))completionHandler
{
	NSURL *webFingerAccountLookupURL;

	if ((webFingerAccountLookupURL = options[OCAuthenticationMethodWebFingerAccountLookupURLKey]) != nil)
	{
		// Send authenticated request to webfinger account lookup URL to retrieve list of available servers
		OCHTTPRequest *request = [OCHTTPRequest requestWithURL:webFingerAccountLookupURL];

		request = [OCAuthenticationMethod authorizeRequest:request withAuthenticationMethodIdentifier:authenticationMethodIdentifier authenticationData:authenticationData];

		request.ephermalResultHandler = ^(OCHTTPRequest * _Nonnull request, OCHTTPResponse * _Nullable response, NSError * _Nullable error) {
			if (error != nil)
			{
				completionHandler(error, nil);
				return;
			}

			if (response.status.isSuccess)
			{
				NSError *jsonError = nil;
				NSDictionary *jsonDict = nil;
				NSMutableArray<OCServerInstance *> *serverInstances = nil;

				if ((jsonDict = [response bodyConvertedDictionaryFromJSONWithError:&jsonError]) != nil)
				{
					NSArray<NSDictionary<NSString*,id> *> *linksArray;

					// Look for first link with relation http://openid.net/specs/connect/1.0/issuer
					if ((linksArray = OCTypedCast(jsonDict[@"links"], NSArray)) != nil)
					{
						serverInstances = [NSMutableArray new];

						for (id link in linksArray)
						{
							NSDictionary<NSString*,id> *linkDict;

							if ((linkDict = OCTypedCast(link, NSDictionary)) != nil)
							{
								if ([linkDict[@"rel"] isEqual:@"http://webfinger.owncloud/rel/server-instance"])
								{
									NSString *urlString;
									NSURL *serverURL = nil;
									NSDictionary <NSString *, NSString *> *titlesByLanguageCode = nil;

									if ((urlString = OCTypedCast(linkDict[@"href"],NSString)) != nil)
									{
										if ((serverURL = [NSURL URLWithString:urlString]) == nil)
										{
											OCLogDebug(@"Server instance href '%@' could not be converted into server URL.", urlString); // This debug message also serves to retain self in this block, to avoid the OCConnection from being deallocated before the completion handler is called
										}
									}

									if ((titlesByLanguageCode = OCTypedCast(linkDict[@"titles"],NSDictionary)) != nil)
									{
										// Ensure that "titles" dictionary contains only strings, reject it otherwise
										__block BOOL isNotAllStrings = NO;

										[titlesByLanguageCode enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
											if (![key isKindOfClass:NSString.class] || ![obj isKindOfClass:NSString.class])
											{
												isNotAllStrings = YES;
												*stop = YES;
											}
										}];

										if (isNotAllStrings)
										{
											titlesByLanguageCode = nil;
										}
									}

									if (serverURL != nil)
									{
										OCServerInstance *instance = [[OCServerInstance alloc] initWithURL:serverURL];

										instance.titlesByLanguageCode = titlesByLanguageCode;

										[serverInstances addObject:instance];
									}
								}
							}
						}
					}
				}

				completionHandler((serverInstances == nil) ? OCError(OCErrorWebFingerLacksServerInstanceRelation) : nil, serverInstances);
			}
			else
			{
				completionHandler(response.status.error, nil);
			}
		};

		if ((request != nil) && (self.ephermalPipeline != nil))
		{
			[self.ephermalPipeline enqueueRequest:request forPartitionID:self.partitionID isFinal:YES];
		}
		else
		{
			completionHandler(OCError(OCErrorInternal), nil);
		}
	}
	else if (_bookmark.url != nil)
	{
		// Return instance based on bookmark URL
		OCServerInstance *instance = [[OCServerInstance alloc] initWithURL:_bookmark.url];
		completionHandler(nil, @[ instance ]);
	}
	else
	{
		// Return nil
		completionHandler(OCError(OCErrorInternal), nil);
	}
}

@end


#pragma mark - Single request authentication
@implementation OCAuthenticationMethod (RequestAuthentication)
+ (OCHTTPRequest *)authorizeRequest:(OCHTTPRequest *)request withAuthenticationMethodIdentifier:(OCAuthenticationMethodIdentifier)authenticationMethodIdentifier authenticationData:(NSData *)authenticationData
{
	OCBookmark *bookmark = [OCBookmark new];
	bookmark.authenticationDataStorage = OCBookmarkAuthenticationDataStorageMemory;
	bookmark.authenticationMethodIdentifier = authenticationMethodIdentifier;
	bookmark.authenticationData = authenticationData;

	OCConnection *connection = [[OCConnection alloc] initWithBookmark:bookmark];

	return ([connection.authenticationMethod authorizeRequest:request forConnection:connection]);
}

@end
