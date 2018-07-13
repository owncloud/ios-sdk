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

- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (IBAction)connectAndGetInfo:(id)sender
{
	if ((bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:self.serverURLField.text]]) != nil)
	{
		if ((connection = [[OCConnection alloc] initWithBookmark:bookmark persistentStoreBaseURL:nil]) != nil)
		{
			[connection generateAuthenticationDataWithMethod:OCAuthenticationMethodOAuth2Identifier options:@{ OCAuthenticationMethodPresentingViewControllerKey : self } completionHandler:^(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData) {
				[self appendLog:[NSString stringWithFormat:@"## generateAuthenticationDataWithMethod response:\nError: %@\nMethod: %@\nData: %@", error, authenticationMethodIdentifier, authenticationData]];

				[self appendLog:[NSString stringWithFormat:@"## User: %@", [[OCAuthenticationMethod registeredAuthenticationMethodForIdentifier:authenticationMethodIdentifier] userNameFromAuthenticationData:authenticationData]]];
				
				if (error == nil)
				{
					bookmark.authenticationMethodIdentifier = authenticationMethodIdentifier;
					bookmark.authenticationData = authenticationData;

					// Request resource
					OCConnectionRequest *request = nil;
					request = [OCConnectionRequest requestWithURL:[connection URLForEndpoint:OCConnectionEndpointIDCapabilities options:nil]];
					[request setValue:@"json" forParameter:@"format"];
		
					[connection sendRequest:request toQueue:connection.commandQueue ephermalCompletionHandler:^(OCConnectionRequest *request, NSError *error) {
						[self appendLog:[NSString stringWithFormat:@"## Endpoint capabilities response:\nResult of request: %@ (error: %@):\nTask: %@\n\nResponse: %@\n\nBody: %@", request, error, request.urlSessionTask, request.response, request.responseBodyAsString]];
						
						if (request.responseHTTPStatus.isSuccess)
						{
							NSError *error = nil;
							NSDictionary *capabilitiesDict;
							
							capabilitiesDict = [request responseBodyConvertedDictionaryFromJSONWithError:&error];
							
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
		OCConnection *connection = [[OCConnection alloc] initWithBookmark:bookmark persistentStoreBaseURL:nil];
		OCConnectionRequest *request = [OCConnectionRequest requestWithURL:connection.bookmark.url];

		request.forceCertificateDecisionDelegation = YES;
		request.ephermalRequestCertificateProceedHandler = ^(OCConnectionRequest *request, OCCertificate *certificate, OCCertificateValidationResult validationResult, NSError *certificateValidationError, OCConnectionCertificateProceedHandler proceedHandler) {

			[[NSOperationQueue mainQueue] addOperationWithBlock:^{
				[self presentViewController:[[UINavigationController alloc] initWithRootViewController:[[OCCertificateViewController alloc] initWithCertificate:certificate]] animated:YES completion:nil];

				[OCCertificateDetailsViewNode certificateDetailsViewNodesForCertificate:certificate withValidationCompletionHandler:^(NSArray<OCCertificateDetailsViewNode *> *detailsViewNodes) {

					[[NSOperationQueue mainQueue] addOperationWithBlock:^{
						NSError *parseError;
						NSMutableAttributedString *attributedString;

						attributedString = [[NSMutableAttributedString alloc] initWithAttributedString:[OCCertificateDetailsViewNode attributedStringWithCertificateDetails:detailsViewNodes]];

						[attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"\n\n------\nCertificate metadata:\n%@\nError: %@", [certificate metaDataWithError:&parseError], parseError]]];

						_logTextView.attributedText = attributedString;
					}];
				}];
			}];

			proceedHandler(YES, nil);
		};

		[connection sendSynchronousRequest:request toQueue:connection.commandQueue];
	}
}

- (void)appendLog:(NSString *)appendToLogString
{
	dispatch_async(dispatch_get_main_queue(), ^{
		_logTextView.text = [_logTextView.text stringByAppendingFormat:@"\n%@ ---------------------------------\n%@", [NSDate date], appendToLogString];
		[_logTextView scrollRangeToVisible:NSMakeRange(_logTextView.text.length-1, 1)];
	});
}

@end
