//
//  OCAuthenticationBrowserSessionUIWebView.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 02.12.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCAuthenticationBrowserSessionUIWebView.h"
#import "OCFeatureAvailability.h"
#import "NSError+OCError.h"
#import "OCLogger.h"

#if OC_FEATURE_AVAILABLE_UIWEBVIEW_BROWSER_SESSION

@interface OCAuthenticationBrowserSessionUIWebView () <UIWebViewDelegate>
{
	UINavigationController *_navigationController;

	UIWebView *_webView;
	UIBarButtonItem *_backButton;
	UIBarButtonItem *_forwardButton;
}
@end

@implementation OCAuthenticationBrowserSessionUIWebView

- (void)clearCaches
{
	// Clear memory + disk cache
	[[NSURLCache sharedURLCache] removeAllCachedResponses];

	// Disable disk cache
	[[NSURLCache sharedURLCache] setDiskCapacity:0];

	// Clear cookies
	[[NSHTTPCookieStorage sharedHTTPCookieStorage] removeCookiesSinceDate:NSDate.distantPast];
}

- (UIViewController *)viewController
{
	if (_viewController == nil)
	{
		[self clearCaches];

		_webView = [UIWebView new];
		_webView.allowsLinkPreview = NO;
		_webView.allowsInlineMediaPlayback = NO;
		_webView.allowsPictureInPictureMediaPlayback = NO;
		_webView.mediaPlaybackAllowsAirPlay = NO;
		_webView.dataDetectorTypes = UIDataDetectorTypeNone;
		_webView.delegate = self;

		_backButton = [[UIBarButtonItem alloc] initWithTitle:@"❮" style:UIBarButtonItemStylePlain target:_webView action:@selector(goBack)];
		_forwardButton = [[UIBarButtonItem alloc] initWithTitle:@"❯" style:UIBarButtonItemStylePlain target:_webView action:@selector(goForward)];

		[_webView addObserver:self forKeyPath:@"canGoBack" options:NSKeyValueObservingOptionInitial context:(__bridge void *)self];
		[_webView addObserver:self forKeyPath:@"canGoForward" options:NSKeyValueObservingOptionInitial context:(__bridge void *)self];

		_viewController = [UIViewController new];
		_viewController.view = _webView;
		_viewController.toolbarItems = @[
			_backButton,
			_forwardButton
		];

		_viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
	}

	return (_viewController);
}

- (void)dealloc
{
	if (_webView != nil)
	{
		[_webView removeObserver:self forKeyPath:@"canGoBack" context:(__bridge void *)self];
		[_webView removeObserver:self forKeyPath:@"canGoForward" context:(__bridge void *)self];
		_webView = nil;
	}

	[self clearCaches];
}

- (BOOL)start
{
	if ((self.hostViewController != nil) && (self.viewController != nil))
	{
		if ((_navigationController = [[UINavigationController alloc] initWithRootViewController:self.viewController]) != nil)
		{
			UIViewController *hostViewController = self.hostViewController;

			while (hostViewController.presentedViewController != nil)
			{
				hostViewController = hostViewController.presentedViewController;
			};

			_navigationController.toolbarHidden = NO;
			_navigationController.modalPresentationStyle = UIModalPresentationFullScreen;

			[_webView loadRequest:[NSURLRequest requestWithURL:self.url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30]];

			[hostViewController presentViewController:_navigationController animated:YES completion:nil];
		}

		return (YES);
	}

	return (NO);
}

#pragma mark - Navigation
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
	if (context == (__bridge void *)self)
	{
		if ([keyPath isEqual:@"canGoBack"] || [keyPath isEqual:@"canGoForward"])
		{
			[self updateNavigationButtons];
		}
	}
}

- (void)updateNavigationButtons
{
	_backButton.enabled = _webView.canGoBack;
	_forwardButton.enabled = _webView.canGoForward;
}

- (void)cancel:(id)sender
{
	[_navigationController.presentingViewController dismissViewControllerAnimated:YES completion:^{
		[self completedWithCallbackURL:nil error:OCError(OCErrorAuthorizationCancelled)];
	}];
}

#pragma mark - Web view delegate
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	if ([request.URL.scheme isEqual:self.scheme])
	{
		[_navigationController.presentingViewController dismissViewControllerAnimated:YES completion:^{
			[self completedWithCallbackURL:request.URL error:nil];
		}];
		return (NO);
	}
	else
	{
		_viewController.navigationItem.title = (request.URL.host!=nil) ? request.URL.host : @"";
		[self updateNavigationButtons];
	}

	return (YES);
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
	[self updateNavigationButtons];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	[self updateNavigationButtons];
}

@end

#endif /* OC_FEATURE_AVAILABLE_UIWEBVIEW_BROWSER_SESSION */
