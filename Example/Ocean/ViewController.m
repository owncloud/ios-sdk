//
//  ViewController.m
//  Ocean
//
//  Created by Felix Schwarz on 16.02.18.
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

#import "ViewController.h"
#import <ownCloudSDK/ownCloudSDK.h>
#import <ownCloudUI/ownCloudUI.h>

@interface ViewController ()
{
	OCBookmark *bookmark;
	OCConnection *connection;
}

@end

@implementation ViewController

- (IBAction)connectAndGetInfo:(id)sender
{
	if ((bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:self.serverURLField.text]]) != nil)
	{
		if ((connection = [[OCConnection alloc] initWithBookmark:bookmark]) != nil)
		{
			[connection generateAuthenticationDataWithMethod:OCAuthenticationMethodIdentifierOAuth2 options:@{ OCAuthenticationMethodPresentingViewControllerKey : self } completionHandler:^(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData) {
				[self appendLog:[NSString stringWithFormat:@"## generateAuthenticationDataWithMethod response:\nError: %@\nMethod: %@\nData: %@", error, authenticationMethodIdentifier, authenticationData]];

				[self appendLog:[NSString stringWithFormat:@"## User: %@", [[OCAuthenticationMethod registeredAuthenticationMethodForIdentifier:authenticationMethodIdentifier] userNameFromAuthenticationData:authenticationData]]];
				
				if (error == nil)
				{
					self->bookmark.authenticationMethodIdentifier = authenticationMethodIdentifier;
					self->bookmark.authenticationData = authenticationData;

					// Request resource
					OCHTTPRequest *request = nil;
					request = [OCHTTPRequest requestWithURL:[self->connection URLForEndpoint:OCConnectionEndpointIDCapabilities options:nil]];
					[request setValue:@"json" forParameter:@"format"];
		
					[self->connection sendRequest:request ephermalCompletionHandler:^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
						[self appendLog:[NSString stringWithFormat:@"## Endpoint capabilities response:\nResult of request: %@ (error: %@):\n\nResponse: %@\n\nBody: %@", request, error, request.httpResponse, request.httpResponse.bodyAsString]];
						
						if (request.httpResponse.status.isSuccess)
						{
							NSError *error = nil;
							NSDictionary *capabilitiesDict;
							
							capabilitiesDict = [request.httpResponse bodyConvertedDictionaryFromJSONWithError:&error];
							
							[self appendLog:[NSString stringWithFormat:@"Capabilities: %@", capabilitiesDict]];
							[self appendLog:[NSString stringWithFormat:@"Version: %@", [capabilitiesDict valueForKeyPath:@"ocs.data.version.string"]]];
						}
					}];
				}
			}];
		}
	}
}

- (IBAction)showCertificate:(id)sender
{
	if ((bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:self.serverURLField.text]]) != nil)
	{
		OCConnection *connection = [[OCConnection alloc] initWithBookmark:bookmark];
		OCHTTPRequest *request = [OCHTTPRequest requestWithURL:connection.bookmark.url];

		request.forceCertificateDecisionDelegation = YES;
		request.ephermalRequestCertificateProceedHandler = ^(OCHTTPRequest *request, OCCertificate *certificate, OCCertificateValidationResult validationResult, NSError *certificateValidationError, OCConnectionCertificateProceedHandler proceedHandler) {

			[[NSOperationQueue mainQueue] addOperationWithBlock:^{
				[self presentViewController:[[UINavigationController alloc] initWithRootViewController:[[OCCertificateViewController alloc] initWithCertificate:certificate]] animated:YES completion:nil];

				[OCCertificateDetailsViewNode certificateDetailsViewNodesForCertificate:certificate withValidationCompletionHandler:^(NSArray<OCCertificateDetailsViewNode *> *detailsViewNodes) {

					[[NSOperationQueue mainQueue] addOperationWithBlock:^{
						NSError *parseError;
						NSMutableAttributedString *attributedString;

						attributedString = [[NSMutableAttributedString alloc] initWithAttributedString:[OCCertificateDetailsViewNode attributedStringWithCertificateDetails:detailsViewNodes]];

						[attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"\n\n------\nCertificate metadata:\n%@\nError: %@", [certificate metaDataWithError:&parseError], parseError]]];

						self->_logTextView.attributedText = attributedString;
					}];
				}];
			}];

			proceedHandler(YES, nil);
		};

		[connection sendSynchronousRequest:request];
	}
}

- (void)appendLog:(NSString *)appendToLogString
{
	dispatch_async(dispatch_get_main_queue(), ^{
		self->_logTextView.text = [self->_logTextView.text stringByAppendingFormat:@"\n%@ ---------------------------------\n%@", [NSDate date], appendToLogString];
		[self->_logTextView scrollRangeToVisible:NSMakeRange(self->_logTextView.text.length-1, 1)];
	});
}

@end
